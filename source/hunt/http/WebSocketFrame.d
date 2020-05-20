module hunt.http.WebSocketFrame;

import hunt.io.ByteBuffer;
import hunt.Exceptions;
import hunt.util.Common;

import std.conv;
import std.traits;


alias OutgoingFramesHandler = void delegate(WebSocketFrame frame, Callback callback);


/**
 * 
 */
enum WebSocketFrameType : byte {
    CONTINUATION = 0x00,
    TEXT = 0x01,
    BINARY = 0x02,
    CLOSE = 0x08,
    PING = 0x09,
    PONG = 0x0A
}


deprecated("Using WebSocketFrameType instead.")
alias FrameType = WebSocketFrameType;

deprecated("Using WebSocketFrame instead.")
alias Frame = WebSocketFrame;


/**
 * An immutable websocket frame.
 */
interface WebSocketFrame {
    deprecated("Using WebSocketFrameType instead.")
    alias Type = WebSocketFrameType;
    // enum Type : byte {
    //     CONTINUATION = 0x00,
    //     TEXT = 0x01,
    //     BINARY = 0x02,
    //     CLOSE = 0x08,
    //     PING = 0x09,
    //     PONG = 0x0A
    // }

    byte[] getMask();

    byte getOpCode();

    ByteBuffer getPayload();

    /**
     * The original payload length ({@link ByteBuffer#remaining()})
     *
     * @return the original payload length ({@link ByteBuffer#remaining()})
     */
    int getPayloadLength();

    WebSocketFrameType getType();

    bool hasPayload();

    bool isFin();

    bool isMasked();

    bool isRsv1();

    bool isRsv2();

    bool isRsv3();
}


/**
 * 
 */
struct OpCode {
    /**
     * OpCode for a Continuation Frame
     *
     * @see <a href="https://tools.ietf.org/html/rfc6455#section-11.8">RFC 6455, Section 11.8 (WebSocket Opcode Registry</a>
     */
    enum byte CONTINUATION = cast(byte) 0x00;

    /**
     * OpCode for a Text Frame
     *
     * @see <a href="https://tools.ietf.org/html/rfc6455#section-11.8">RFC 6455, Section 11.8 (WebSocket Opcode Registry</a>
     */
    enum byte TEXT = cast(byte) 0x01;

    /**
     * OpCode for a Binary Frame
     *
     * @see <a href="https://tools.ietf.org/html/rfc6455#section-11.8">RFC 6455, Section 11.8 (WebSocket Opcode Registry</a>
     */
    enum byte BINARY = cast(byte) 0x02;

    /**
     * OpCode for a Close Frame
     *
     * @see <a href="https://tools.ietf.org/html/rfc6455#section-11.8">RFC 6455, Section 11.8 (WebSocket Opcode Registry</a>
     */
    enum byte CLOSE = cast(byte) 0x08;

    /**
     * OpCode for a Ping Frame
     *
     * @see <a href="https://tools.ietf.org/html/rfc6455#section-11.8">RFC 6455, Section 11.8 (WebSocket Opcode Registry</a>
     */
    enum byte PING = cast(byte) 0x09;

    /**
     * OpCode for a Pong Frame
     *
     * @see <a href="https://tools.ietf.org/html/rfc6455#section-11.8">RFC 6455, Section 11.8 (WebSocket Opcode Registry</a>
     */
    enum byte PONG = cast(byte) 0x0A;

    /**
     * An undefined OpCode
     */
    enum byte UNDEFINED = cast(byte) -1;

    static bool isControlFrame(byte opcode) {
        return (opcode >= CLOSE);
    }

    static bool isDataFrame(byte opcode) {
        return (opcode == TEXT) || (opcode == BINARY);
    }

    /**
     * Test for known opcodes (per the RFC spec)
     *
     * @param opcode the opcode to test
     * @return true if known. false if unknown, undefined, or reserved
     */
    static bool isKnown(byte opcode) {
        return (opcode == CONTINUATION) || (opcode == TEXT) || (opcode == BINARY) || 
            (opcode == CLOSE) || (opcode == PING) || (opcode == PONG);
    }

    static string name(byte opcode) {
        switch (opcode) {
            case -1:
                return "NO-OP";
            case CONTINUATION:
                return "CONTINUATION";
            case TEXT:
                return "TEXT";
            case BINARY:
                return "BINARY";
            case CLOSE:
                return "CLOSE";
            case PING:
                return "PING";
            case PONG:
                return "PONG";
            default:
                return "NON-SPEC[" ~ opcode ~ "]";
        }
    }
}

