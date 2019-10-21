module hunt.http.codec.websocket.decode.Parser;

import hunt.http.codec.websocket.frame;
import hunt.http.codec.websocket.model;
import hunt.http.codec.websocket.decode.payload;

import hunt.http.Exceptions;
import hunt.http.WebSocketCommon;
import hunt.http.WebSocketConnection;
import hunt.http.WebSocketFrame;
import hunt.http.WebSocketPolicy;

import hunt.logging;
import hunt.collection;
import hunt.text.Common;
import hunt.text.StringBuilder;

import std.algorithm;
import std.conv;


/**
 * Parsing of a frames in WebSocket land.
 */
class Parser {
    private enum State {
        START,
        PAYLOAD_LEN,
        PAYLOAD_LEN_BYTES,
        MASK,
        MASK_BYTES,
        PAYLOAD
    }

    private WebSocketPolicy policy;

    // State specific
    private State state = State.START;
    private int cursor = 0;
    // WebSocketFrame
    private AbstractWebSocketFrame frame;
    private bool priorDataFrame;
    // payload specific
    private ByteBuffer payload;
    private int payloadLength;
    private PayloadProcessor maskProcessor;
    // private PayloadProcessor strictnessProcessor;

    /**
     * Is there an extension using RSV flag?
     * <p>
     * <p>
     * <pre>
     *   0100_0000 (0x40) = rsv1
     *   0010_0000 (0x20) = rsv2
     *   0001_0000 (0x10) = rsv3
     * </pre>
     */
    private byte flagsInUse = 0x00;

    private IncomingFrames incomingFramesHandler;

    this(WebSocketPolicy wspolicy) {
        this.policy = wspolicy;
         maskProcessor = new DeMaskProcessor();
    }

    private void assertSanePayloadLength(long len) {
        version(HUNT_HTTP_DEBUG) {
            tracef("%s Payload Length: %s - %s", policy.getBehavior(), 
                len.to!string(), this.toString());
        }

        // Since we use ByteBuffer so often, having lengths over int.max is really impossible.
        if (len > int.max) {
            // OMG! Sanity Check! DO NOT WANT! Won't anyone think of the memory!
            throw new MessageTooLargeException("[int-sane!] cannot handle payload lengths larger than " 
                ~ to!string(int.max));
        }

        switch (frame.getOpCode()) {
            case OpCode.CLOSE:
                if (len == 1) {
                    throw new ProtocolException("Invalid close frame payload length, [" ~ 
                        payloadLength.to!string() ~ "]");
                }
                goto case;
                // fall thru
            case OpCode.PING:
                goto case;
            case OpCode.PONG:
                if (len > ControlFrame.MAX_CONTROL_PAYLOAD) {
                    throw new ProtocolException("Invalid control frame payload length, [" ~ 
                        payloadLength.to!string() ~ "] cannot exceed [" ~ 
                        ControlFrame.MAX_CONTROL_PAYLOAD.to!string() ~ "]");
                }
                break;
            case OpCode.TEXT:
                policy.assertValidTextMessageSize(cast(int) len);
                break;
            case OpCode.BINARY:
                policy.assertValidBinaryMessageSize(cast(int) len);
                break;

            default:
                break;
        }
    }

    void configureFromExtensions(Extension[] exts) {
        // default
        flagsInUse = 0x00;

        // configure from list of extensions in use
        foreach (Extension ext ; exts) {
            if (ext.isRsv1User()) {
                flagsInUse = cast(byte) (flagsInUse | 0x40);
            }
            if (ext.isRsv2User()) {
                flagsInUse = cast(byte) (flagsInUse | 0x20);
            }
            if (ext.isRsv3User()) {
                flagsInUse = cast(byte) (flagsInUse | 0x10);
            }
        }
    }

    IncomingFrames getIncomingFramesHandler() {
        return incomingFramesHandler;
    }

    WebSocketPolicy getPolicy() {
        return policy;
    }

    bool isRsv1InUse() {
        return (flagsInUse & 0x40) != 0;
    }

    bool isRsv2InUse() {
        return (flagsInUse & 0x20) != 0;
    }

    bool isRsv3InUse() {
        return (flagsInUse & 0x10) != 0;
    }

    protected void notifyFrame(WebSocketFrame f) {
        version(HUNT_HTTP_DEBUG_MORE)
            tracef("%s Notify %s", policy.getBehavior(), getIncomingFramesHandler());

        if (policy.getBehavior() == WebSocketBehavior.SERVER) {
            /* Parsing on server.
             * 
             * Then you MUST make sure all incoming frames are masked!
             * 
             * Technically, this test is in violation of RFC-6455, Section 5.1
             * http://tools.ietf.org/html/rfc6455#section-5.1
             * 
             * But we can't trust the client at this point, so hunt opts to close
             * the connection as a Protocol error.
             */
            if (!f.isMasked()) {
                throw new ProtocolException("Client MUST mask all frames (RFC-6455: Section 5.1)");
            }
        } else if (policy.getBehavior() == WebSocketBehavior.CLIENT) {
            // Required by RFC-6455 / Section 5.1
            if (f.isMasked()) {
                throw new ProtocolException("Server MUST NOT mask any frames (RFC-6455: Section 5.1)");
            }
        }
        
        if (incomingFramesHandler is null) {
            version(HUNT_DEBUG) warning("incomingFramesHandler is null");
            return;
        }

        try {
            incomingFramesHandler.incomingFrame(f);
        } catch (WebSocketException e) {
            throw e;
        } catch (Exception t) {
            throw new WebSocketException(t);
        }
    }

    void parse(ByteBuffer buffer) {
        
        version(HUNT_HTTP_DEBUG) {
            byte[] bufdata = buffer.getRemaining();
            tracef("remaining: %d,  date: %(%02X %)", buffer.remaining(), bufdata);
        }

        if (buffer.remaining() <= 0) {
            return;
        }
        try {
            // parse through all the frames in the buffer
            while (parseFrame(buffer)) {
                version(HUNT_DEBUG) {
                    tracef("%s Parsed WebSocketFrame: %s", policy.getBehavior(), frame);
                    // info(BufferUtils.toDetailString(frame.getPayload()));
                }
                notifyFrame(frame);
                if (frame.isDataFrame()) {
                    priorDataFrame = !frame.isFin();
                }
                reset();
            }
        } catch (WebSocketException e) {
            buffer.position(buffer.limit()); // consume remaining
            reset();
            // need to throw for proper close behavior in connection
            throw e;
        } catch (Exception t) {
            buffer.position(buffer.limit()); // consume remaining
            reset();
            // need to throw for proper close behavior in connection
            throw new WebSocketException(t);
        }
    }

    private void reset() {
        if (frame !is null)
            frame.reset();
        frame = null;
        payload = null;
    }

    /**
     * Parse the base framing protocol buffer.
     * <p>
     * Note the first byte (fin,rsv1,rsv2,rsv3,opcode) are parsed by the {@link Parser#parse(ByteBuffer)} method
     * <p>
     * Not overridable
     *
     * @param buffer the buffer to parse from.
     * @return true if done parsing base framing protocol and ready for parsing of the payload. false if incomplete parsing of base framing protocol.
     */
    private bool parseFrame(ByteBuffer buffer) {
        version(HUNT_DEBUG) {
            tracef("%s Parsing %s bytes", policy.getBehavior(), buffer.remaining());
        }
        while (buffer.hasRemaining()) {
            switch (state) {
                case State.START: {
                    // peek at byte
                    byte b = buffer.get();
                    bool fin = ((b & 0x80) != 0);

                    byte opcode = cast(byte) (b & 0x0F);

                    if (!OpCode.isKnown(opcode)) {
                        throw new ProtocolException("Unknown opcode: " ~ opcode);
                    }

                    version(HUNT_DEBUG)
                        tracef("%s OpCode %s, fin=%s rsv=%s%s%s",
                                policy.getBehavior(),
                                OpCode.name(opcode),
                                fin,
                                (((b & 0x40) != 0) ? '1' : '.'),
                                (((b & 0x20) != 0) ? '1' : '.'),
                                (((b & 0x10) != 0) ? '1' : '.'));

                    // base framing flags
                    switch (opcode) {
                        case OpCode.TEXT:
                            frame = new TextFrame();
                            // data validation
                            if (priorDataFrame) {
                                throw new ProtocolException("Unexpected " ~ OpCode.name(opcode) ~ 
                                    " frame, was expecting CONTINUATION");
                            }
                            break;
                        case OpCode.BINARY:
                            frame = new BinaryFrame();
                            // data validation
                            if (priorDataFrame) {
                                throw new ProtocolException("Unexpected " ~ OpCode.name(opcode) ~ 
                                    " frame, was expecting CONTINUATION");
                            }
                            break;
                        case OpCode.CONTINUATION:
                            frame = new ContinuationFrame();
                            // continuation validation
                            if (!priorDataFrame) {
                                throw new ProtocolException("CONTINUATION frame without prior !FIN");
                            }
                            // Be careful to use the original opcode
                            break;
                        case OpCode.CLOSE:
                            frame = new CloseFrame();
                            // control frame validation
                            if (!fin) {
                                throw new ProtocolException("Fragmented Close WebSocketFrame [" ~ 
                                    OpCode.name(opcode) ~ "]");
                            }
                            break;
                        case OpCode.PING:
                            frame = new PingFrame();
                            // control frame validation
                            if (!fin) {
                                throw new ProtocolException("Fragmented Ping WebSocketFrame [" ~ 
                                    OpCode.name(opcode) ~ "]");
                            }
                            break;
                        case OpCode.PONG:
                            frame = new PongFrame();
                            // control frame validation
                            if (!fin) {
                                throw new ProtocolException("Fragmented Pong WebSocketFrame [" ~ 
                                    OpCode.name(opcode) ~ "]");
                            }
                            break;

                        default: break;
                    }

                    frame.setFin(fin);

                    // Are any flags set?
                    if ((b & 0x70) != 0) {
                        /*
                         * RFC 6455 Section 5.2
                         * 
                         * MUST be 0 unless an extension is negotiated that defines meanings for non-zero values. If a nonzero value is received and none of the
                         * negotiated extensions defines the meaning of such a nonzero value, the receiving endpoint MUST _Fail the WebSocket Connection_.
                         */
                        if ((b & 0x40) != 0) {
                            if (isRsv1InUse())
                                frame.setRsv1(true);
                            else {
                                string err = "RSV1 not allowed to be set";
                                version(HUNT_DEBUG) {
                                    tracef(err ~ ": Remaining buffer: %s", BufferUtils.toDetailString(buffer));
                                }
                                throw new ProtocolException(err);
                            }
                        }
                        if ((b & 0x20) != 0) {
                            if (isRsv2InUse())
                                frame.setRsv2(true);
                            else {
                                string err = "RSV2 not allowed to be set";
                                version(HUNT_DEBUG) {
                                    tracef(err ~ ": Remaining buffer: %s", BufferUtils.toDetailString(buffer));
                                }
                                throw new ProtocolException(err);
                            }
                        }
                        if ((b & 0x10) != 0) {
                            if (isRsv3InUse())
                                frame.setRsv3(true);
                            else {
                                string err = "RSV3 not allowed to be set";
                                version(HUNT_DEBUG) {
                                    tracef(err ~ ": Remaining buffer: %s", BufferUtils.toDetailString(buffer));
                                }
                                throw new ProtocolException(err);
                            }
                        }
                    }

                    state = State.PAYLOAD_LEN;
                    break;
                }

                case State.PAYLOAD_LEN: {
                    byte b = buffer.get();
                    frame.setMasked((b & 0x80) != 0);
                    payloadLength = cast(byte) (0x7F & b);

                    if (payloadLength == 127) // 0x7F
                    {
                        // length 8 bytes (extended payload length)
                        payloadLength = 0;
                        state = State.PAYLOAD_LEN_BYTES;
                        cursor = 8;
                        break; // continue onto next state
                    } else if (payloadLength == 126) // 0x7E
                    {
                        // length 2 bytes (extended payload length)
                        payloadLength = 0;
                        state = State.PAYLOAD_LEN_BYTES;
                        cursor = 2;
                        break; // continue onto next state
                    }

                    assertSanePayloadLength(payloadLength);
                    if (frame.isMasked()) {
                        state = State.MASK;
                    } else {
                        // special case for empty payloads (no more bytes left in buffer)
                        if (payloadLength == 0) {
                            state = State.START;
                            return true;
                        }

                        maskProcessor.reset(frame);
                        state = State.PAYLOAD;
                    }

                    break;
                }

                case State.PAYLOAD_LEN_BYTES: {
                    byte b = buffer.get();
                    --cursor;
                    payloadLength |= (b & 0xFF) << (8 * cursor);
                    if (cursor == 0) {
                        assertSanePayloadLength(payloadLength);
                        if (frame.isMasked()) {
                            state = State.MASK;
                        } else {
                            // special case for empty payloads (no more bytes left in buffer)
                            if (payloadLength == 0) {
                                state = State.START;
                                return true;
                            }

                            maskProcessor.reset(frame);
                            state = State.PAYLOAD;
                        }
                    }
                    break;
                }

                case State.MASK: {
                    byte[] m = new byte[4];
                    frame.setMask(m);
                    if (buffer.remaining() >= 4) {
                        buffer.get(m, 0, 4);
                        // special case for empty payloads (no more bytes left in buffer)
                        if (payloadLength == 0) {
                            state = State.START;
                            return true;
                        }

                        maskProcessor.reset(frame);
                        state = State.PAYLOAD;
                    } else {
                        state = State.MASK_BYTES;
                        cursor = 4;
                    }
                    break;
                }

                case State.MASK_BYTES: {
                    byte b = buffer.get();
                    frame.getMask()[4 - cursor] = b;
                    --cursor;
                    if (cursor == 0) {
                        // special case for empty payloads (no more bytes left in buffer)
                        if (payloadLength == 0) {
                            state = State.START;
                            return true;
                        }

                        maskProcessor.reset(frame);
                        state = State.PAYLOAD;
                    }
                    break;
                }

                case State.PAYLOAD: {
                    frame.assertValid();
                    if (parsePayload(buffer)) {
                        // special check for close
                        if (frame.getOpCode() == OpCode.CLOSE) {
                            // TODO: yuck. Don't create an object to do validation checks!
                            new CloseInfo(frame);
                        }
                        state = State.START;
                        // we have a frame!
                        return true;
                    }
                    break;
                }

                default: break;
            }
        }

        return false;
    }

    /**
     * Implementation specific parsing of a payload
     *
     * @param buffer the payload buffer
     * @return true if payload is done reading, false if incomplete
     */
    private bool parsePayload(ByteBuffer buffer) {
        if (payloadLength == 0) {
            return true;
        }

        if (buffer.hasRemaining()) {
            // Create a small window of the incoming buffer to work with.
            // this should only show the payload itself, and not any more
            // bytes that could belong to the start of the next frame.
            int bytesSoFar = payload is null ? 0 : payload.position();
            int bytesExpected = payloadLength - bytesSoFar;
            int bytesAvailable = buffer.remaining();
            int windowBytes = std.algorithm.min(bytesAvailable, bytesExpected);
            int limit = buffer.limit();
            buffer.limit(buffer.position() + windowBytes);
            ByteBuffer window = buffer.slice();
            buffer.limit(limit);
            buffer.position(buffer.position() + window.remaining());

            maskProcessor.process(window);

            version(HUNT_HTTP_DEBUG) {
                tracef("%s Window(unmarked): %s", policy.getBehavior(), BufferUtils.toDetailString(window));
            }

            if (window.remaining() == payloadLength) {
                // We have the whole content, no need to copy.
                frame.setPayload(window);
                return true;
            } else {
                if (payload is null) {
                    payload = BufferUtils.allocate(payloadLength);
                    BufferUtils.clearToFill(payload);
                }
                // Copy the payload.
                payload.put(window);

                if (payload.position() == payloadLength) {
                    BufferUtils.flipToFlush(payload, 0);
                    frame.setPayload(payload);
                    return true;
                }
            }
        }
        return false;
    }

    void setIncomingFramesHandler(IncomingFrames incoming) {
        this.incomingFramesHandler = incoming;
    }

    override
    string toString() {
        StringBuilder builder = new StringBuilder();
        builder.append("Parser@").append(toHash().to!string(16));
        builder.append("[");
        if (incomingFramesHandler is null) {
            builder.append("NO_HANDLER");
        } else {
            builder.append(typeid(incomingFramesHandler).name);
        }
        builder.append(",s=").append(state.to!string());
        builder.append(",c=").append(cursor.to!string());
        builder.append(",len=").append(payloadLength);
        builder.append(",f=").append(frame.toString());
        // builder.append(",p=").append(policy);
        builder.append("]");
        return builder.toString();
    }
}
