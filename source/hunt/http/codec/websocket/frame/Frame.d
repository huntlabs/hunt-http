module hunt.http.codec.websocket.frame.Frame;

import hunt.collection.ByteBuffer;
import hunt.Exceptions;
import std.conv;


deprecated("Using WebSocketFrameType instead.")
alias FrameType = WebSocketFrameType;


enum WebSocketFrameType : byte {
    CONTINUATION = 0x00,
    TEXT = 0x01,
    BINARY = 0x02,
    CLOSE = 0x08,
    PING = 0x09,
    PONG = 0x0A
}

/**
 * An immutable websocket frame.
 */
interface Frame {
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

import std.traits;

class FrameTypeHelper {
    
        static WebSocketFrameType from(byte op) {
            foreach (WebSocketFrameType type ; EnumMembers!(WebSocketFrameType)) {
                if (cast(byte)type == op) 
                    return type;
            }
            throw new IllegalArgumentException("OpCode " ~ to!string(op) ~ 
                " is not a valid Frame.Type");
        }

        static bool isControl(WebSocketFrameType type) {
            return type >= WebSocketFrameType.CLOSE;
        }

        bool isData(WebSocketFrameType type) {
            return (type == WebSocketFrameType.TEXT) || (type == WebSocketFrameType.BINARY);
        }

        bool isContinuation(WebSocketFrameType type) {
            return type == WebSocketFrameType.CONTINUATION;
        }

}