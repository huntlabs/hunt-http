module hunt.http.codec.websocket.frame.Frame;

import hunt.container.ByteBuffer;

import hunt.util.exception;

import std.conv;

alias FrameType = Frame.Type;

/**
 * An immutable websocket frame.
 */
interface Frame {
    enum Type : byte {
        CONTINUATION = 0x00,
        TEXT = 0x01,
        BINARY = 0x02,
        CLOSE = 0x08,
        PING = 0x09,
        PONG = 0x0A
    }

    byte[] getMask();

    byte getOpCode();

    ByteBuffer getPayload();

    /**
     * The original payload length ({@link ByteBuffer#remaining()})
     *
     * @return the original payload length ({@link ByteBuffer#remaining()})
     */
    int getPayloadLength();

    Type getType();

    bool hasPayload();

    bool isFin();

    bool isMasked();

    bool isRsv1();

    bool isRsv2();

    bool isRsv3();
}

import std.traits;

class FrameTypeHelper {
    
        static FrameType from(byte op) {
            foreach (FrameType type ; EnumMembers!(FrameType)) {
                if (cast(byte)type == op) 
                    return type;
            }
            throw new IllegalArgumentException("OpCode " ~ to!string(op) ~ 
                " is not a valid Frame.Type");
        }

        static bool isControl(FrameType type) {
            return type >= FrameType.CLOSE;
        }

        bool isData(FrameType type) {
            return (type == FrameType.TEXT) || (type == FrameType.BINARY);
        }

        bool isContinuation(FrameType type) {
            return type == FrameType.CONTINUATION;
        }

}