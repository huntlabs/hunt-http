module hunt.http.codec.websocket.model;

final class OpCode {
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
