module hunt.http.codec.http.decode.BodyParser;

import hunt.http.codec.http.decode.HeaderParser;
import hunt.http.codec.http.decode.Parser;
import hunt.http.codec.http.decode.Parser;
import hunt.http.codec.http.frame;

import hunt.container.BufferUtils;
import hunt.container.ByteBuffer;

import kiss.logger;



/**
 * <p>
 * The base parser for the frame body of HTTP/2 frames.
 * </p>
 * <p>
 * Subclasses implement {@link #parse(ByteBuffer)} to parse the frame specific
 * body.
 * </p>
 *
 * @see Parser
 */
abstract class BodyParser {
    // 

    private HeaderParser headerParser;
    private Parser.Listener listener;

    protected this(HeaderParser headerParser, Parser.Listener listener) {
        this.headerParser = headerParser;
        this.listener = listener;
    }

    /**
     * <p>
     * Parses the body bytes in the given {@code buffer}; only the body bytes
     * are consumed, therefore when this method returns, the buffer may contain
     * unconsumed bytes.
     * </p>
     *
     * @param buffer the buffer to parse
     * @return true if the whole body bytes were parsed, false if not enough
     * body bytes were present in the buffer
     */
    abstract bool parse(ByteBuffer buffer);

    void emptyBody(ByteBuffer buffer) {
        connectionFailure(buffer, cast(int)ErrorCode.PROTOCOL_ERROR, "invalid_frame");
    }

    protected bool hasFlag(int bit) {
        return headerParser.hasFlag(bit);
    }

    protected bool isPadding() {
        return headerParser.hasFlag(Flags.PADDING);
    }

    protected bool isEndStream() {
        return headerParser.hasFlag(Flags.END_STREAM);
    }

    protected int getStreamId() {
        return headerParser.getStreamId();
    }

    protected int getBodyLength() {
        return headerParser.getLength();
    }

    protected void notifyData(DataFrame frame) {
        try {
            listener.onData(frame);
        } catch (Exception x) {
            errorf("Failure while notifying listener %s", x, listener);
        }
    }

    protected void notifyHeaders(HeadersFrame frame) {
        try {
            listener.onHeaders(frame);
        } catch (Exception x) {
            errorf("Failure while notifying listener %s", x, listener);
        }
    }

    protected void notifyPriority(PriorityFrame frame) {
        try {
            listener.onPriority(frame);
        } catch (Exception x) {
            errorf("Failure while notifying listener %s", x, listener);
        }
    }

    protected void notifyReset(ResetFrame frame) {
        try {
            listener.onReset(frame);
        } catch (Exception x) {
            errorf("Failure while notifying listener %s", x, listener);
        }
    }

    protected void notifySettings(SettingsFrame frame) {
        try {
            listener.onSettings(frame);
        } catch (Exception x) {
            errorf("Failure while notifying listener %s", x, listener);
        }
    }

    protected void notifyPushPromise(PushPromiseFrame frame) {
        try {
            listener.onPushPromise(frame);
        } catch (Exception x) {
            errorf("Failure while notifying listener %s", x, listener);
        }
    }

    protected void notifyPing(PingFrame frame) {
        try {
            listener.onPing(frame);
        } catch (Exception x) {
            errorf("Failure while notifying listener %s", x, listener);
        }
    }

    protected void notifyGoAway(GoAwayFrame frame) {
        try {
            listener.onGoAway(frame);
        } catch (Exception x) {
            errorf("Failure while notifying listener %s", x, listener);
        }
    }

    protected void notifyWindowUpdate(WindowUpdateFrame frame) {
        try {
            listener.onWindowUpdate(frame);
        } catch (Exception x) {
            errorf("Failure while notifying listener %s", x, listener);
        }
    }

    protected bool connectionFailure(ByteBuffer buffer, int error, string reason) {
        BufferUtils.clear(buffer);
        notifyConnectionFailure(error, reason);
        return false;
    }

    private void notifyConnectionFailure(int error, string reason) {
        try {
            listener.onConnectionFailure(error, reason);
        } catch (Exception x) {
            errorf("Failure while notifying listener %s", x, listener);
        }
    }
}
