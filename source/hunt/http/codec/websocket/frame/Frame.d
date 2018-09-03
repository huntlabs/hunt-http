module hunt.http.codec.websocket.frame;

import hunt.container.ByteBuffer;

/**
 * An immutable websocket frame.
 */
interface Frame {
    enum Type {
        CONTINUATION((byte) 0x00),
        TEXT((byte) 0x01),
        BINARY((byte) 0x02),
        CLOSE((byte) 0x08),
        PING((byte) 0x09),
        PONG((byte) 0x0A);

        static Type from(byte op) {
            for (Type type : values()) {
                if (type.opcode == op) {
                    return type;
                }
            }
            throw new IllegalArgumentException("OpCode " + op + " is not a valid Frame.Type");
        }

        private byte opcode;

        Type(byte code) {
            this.opcode = code;
        }

        byte getOpCode() {
            return opcode;
        }

        bool isControl() {
            return (opcode >= CLOSE.getOpCode());
        }

        bool isData() {
            return (opcode == TEXT.getOpCode()) || (opcode == BINARY.getOpCode());
        }

        bool isContinuation() {
            return opcode == CONTINUATION.getOpCode();
        }

        override
        string toString() {
            return this.name();
        }
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
