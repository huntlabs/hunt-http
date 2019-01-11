module hunt.http.codec.http.decode.Parser;

import hunt.http.codec.http.frame;
import hunt.http.codec.http.hpack.HpackDecoder;

import hunt.http.codec.http.decode.BodyParser;
import hunt.http.codec.http.decode.ContinuationBodyParser;
import hunt.http.codec.http.decode.DataBodyParser;
import hunt.http.codec.http.decode.HeaderParser;
import hunt.http.codec.http.decode.HeaderBlockParser;
import hunt.http.codec.http.decode.HeaderBlockFragments;
import hunt.http.codec.http.decode.HeadersBodyParser;
import hunt.http.codec.http.decode.GoAwayBodyParser;
import hunt.http.codec.http.decode.PingBodyParser;
import hunt.http.codec.http.decode.PriorityBodyParser;
import hunt.http.codec.http.decode.PushPromiseBodyParser;
import hunt.http.codec.http.decode.ResetBodyParser;
import hunt.http.codec.http.decode.SettingsBodyParser;
import hunt.http.codec.http.decode.WindowUpdateBodyParser;

import hunt.collection.BufferUtils;
import hunt.collection.ByteBuffer;

import hunt.Exceptions;

import hunt.logging;

import std.conv;
import std.stdio;



/**
 * <p>
 * The HTTP/2 protocol parser.
 * </p>
 * <p>
 * This parser makes use of the {@link HeaderParser} and of {@link BodyParser}s
 * to parse HTTP/2 frames.
 * </p>
 */
class Parser {
    

    private Listener listener;
    private HeaderParser headerParser;
    private BodyParser[FrameType] bodyParsers;
    private bool continuation;
    private State state = State.HEADER;

    this(Listener listener, int maxDynamicTableSize, int maxHeaderSize) {
        this.listener = listener;
        this.headerParser = new HeaderParser();
        // this.bodyParsers = new BodyParser[FrameTypeSize];

        HeaderBlockParser headerBlockParser = new HeaderBlockParser(new HpackDecoder(maxDynamicTableSize, maxHeaderSize));
        HeaderBlockFragments headerBlockFragments = new HeaderBlockFragments();

        bodyParsers[FrameType.DATA] = new DataBodyParser(headerParser, listener);
        bodyParsers[FrameType.HEADERS] = new HeadersBodyParser(headerParser, listener, headerBlockParser, headerBlockFragments);
        bodyParsers[FrameType.PRIORITY] = new PriorityBodyParser(headerParser, listener);
        bodyParsers[FrameType.RST_STREAM] = new ResetBodyParser(headerParser, listener);
        bodyParsers[FrameType.SETTINGS] = new SettingsBodyParser(headerParser, listener);
        bodyParsers[FrameType.PUSH_PROMISE] = new PushPromiseBodyParser(headerParser, listener, headerBlockParser);
        bodyParsers[FrameType.PING] = new PingBodyParser(headerParser, listener);
        bodyParsers[FrameType.GO_AWAY] = new GoAwayBodyParser(headerParser, listener);
        bodyParsers[FrameType.WINDOW_UPDATE] = new WindowUpdateBodyParser(headerParser, listener);
        bodyParsers[FrameType.CONTINUATION] = new ContinuationBodyParser(headerParser, listener, headerBlockParser, headerBlockFragments);
    }

    private void reset() {
        headerParser.reset();
        state = State.HEADER;
    }

    /**
     * <p>
     * Parses the given {@code buffer} bytes and emit events to a
     * {@link Listener}.
     * </p>
     * <p>
     * When this method returns, the buffer may not be fully consumed, so
     * invocations to this method should be wrapped in a loop:
     * </p>
     * <p>
     * <pre>
     * while (buffer.hasRemaining())
     * 	parser.parse(buffer);
     * </pre>
     *
     * @param buffer the buffer to parse
     */
    void parse(ByteBuffer buffer) {
        try {
            while (true) {
                switch (state) {
                    case State.HEADER: {
                        if (parseHeader(buffer)) {
                            break;
                        } else {
                            return;
                        }
                    }
                    case State.BODY: {
                        if (parseBody(buffer)) {
                            break;
                        } else {
                            return;
                        }
                    }
                    default: {
                        throw new IllegalStateException("");
                    }
                }
            }
        } catch (Exception x) {
            errorf("HTTP2 parsing error", x);
            BufferUtils.clear(buffer);
            notifyConnectionFailure(cast(int)ErrorCode.PROTOCOL_ERROR, "parser_error");
        }
    }

    protected bool parseHeader(ByteBuffer buffer) {
        if (headerParser.parse(buffer)) {
            int frameType = getFrameType();
            version(HUNT_DEBUG) {
                tracef("Parsed %s frame header", cast(FrameType)(frameType));
            }

            if (continuation) {
                if (frameType != FrameType.CONTINUATION) {
                    // SPEC: CONTINUATION frames must be consecutive.
                    BufferUtils.clear(buffer);
                    notifyConnectionFailure(cast(int)ErrorCode.PROTOCOL_ERROR, "continuation_frame_expected");
                    return false;
                }
                if (headerParser.hasFlag(Flags.END_HEADERS)) {
                    continuation = false;
                }
            } else {
                if (frameType == FrameType.HEADERS && !headerParser.hasFlag(Flags.END_HEADERS)) {
                    continuation = true;
                }
            }
            state = State.BODY;
            return true;
        } else {
            return false;
        }
    }

    protected bool parseBody(ByteBuffer buffer) {
        int type = getFrameType();
        if (type < 0 || type >= bodyParsers.length) {
            BufferUtils.clear(buffer);
            notifyConnectionFailure(cast(int)ErrorCode.PROTOCOL_ERROR, "unknown_frame_type_" ~ type.to!string);
            return false;
        }

        FrameType frameType = cast(FrameType)(type);
        version(HUNT_DEBUG) {
            tracef("Parsing %s frame", frameType);
        }
        BodyParser bodyParser = bodyParsers[frameType];
        if (headerParser.getLength() == 0) {
            bodyParser.emptyBody(buffer);
            reset();
            version(HUNT_DEBUG) {
                tracef("Parsed %s frame, empty body", frameType);
            }
            return true;
        } else {
            if (bodyParser.parse(buffer)) {
                reset();
                version(HUNT_DEBUG) {
                    tracef("Parsed %s frame", frameType);
                }
                return true;
            } else {
                return false;
            }
        }
    }

    protected int getFrameType() {
        return headerParser.getFrameType();
    }

    protected bool hasFlag(int bit) {
        return headerParser.hasFlag(bit);
    }

    protected void notifyConnectionFailure(int error, string reason) {
        try {
            listener.onConnectionFailure(error, reason);
        } catch (Exception x) {
            errorf("Failure while notifying listener %s", x, listener);
        }
    }

    interface Listener {
        void onData(DataFrame frame);

        void onHeaders(HeadersFrame frame);

        void onPriority(PriorityFrame frame);

        void onReset(ResetFrame frame);

        void onSettings(SettingsFrame frame);

        void onPushPromise(PushPromiseFrame frame);

        void onPing(PingFrame frame);

        void onGoAway(GoAwayFrame frame);

        void onWindowUpdate(WindowUpdateFrame frame);

        void onConnectionFailure(int error, string reason);

        static class Adapter : Listener {
            override
            void onData(DataFrame frame) {
            }

            override
            void onHeaders(HeadersFrame frame) {
            }

            override
            void onPriority(PriorityFrame frame) {
            }

            override
            void onReset(ResetFrame frame) {
            }

            override
            void onSettings(SettingsFrame frame) {
            }

            override
            void onPushPromise(PushPromiseFrame frame) {
            }

            override
            void onPing(PingFrame frame) {
            }

            override
            void onGoAway(GoAwayFrame frame) {
            }

            override
            void onWindowUpdate(WindowUpdateFrame frame) {
            }

            override
            void onConnectionFailure(int error, string reason) {
                writeln("connection failure -> " ~ error.to!string ~ ", " ~ reason);
                warningf("Connection failure: %d/%s", error, reason);
            }
        }
    }

    private enum State {
        HEADER, BODY
    }
}
