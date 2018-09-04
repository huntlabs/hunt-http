module hunt.http.codec.websocket.model.common;

final class WebSocketConstants {
    enum string SEC_WEBSOCKET_EXTENSIONS = "Sec-WebSocket-Extensions";
    enum string SEC_WEBSOCKET_PROTOCOL = "Sec-WebSocket-Protocol";
    enum string SEC_WEBSOCKET_VERSION = "Sec-WebSocket-Version";
    enum int SPEC_VERSION = 13;
}


/**
 * Behavior for how the WebSocket should operate.
 * <p>
 * This dictated by the <a href="https://tools.ietf.org/html/rfc6455">RFC 6455</a> spec in various places, where certain behavior must be performed depending on
 * operation as a <a href="https://tools.ietf.org/html/rfc6455#section-4.1">CLIENT</a> vs a <a href="https://tools.ietf.org/html/rfc6455#section-4.2">SERVER</a>
 */
enum WebSocketBehavior {
    CLIENT, SERVER
}


/**
 * Connection states as outlined in <a href="https://tools.ietf.org/html/rfc6455">RFC6455</a>.
 */
enum ConnectionState {
    /**
     * [RFC] Initial state of a connection, the upgrade request / response is in progress
     */
    CONNECTING,
    /**
     * [Impl] Intermediate state between CONNECTING and OPEN, used to indicate that a upgrade request/response is successful, but the end-user provided socket's
     * onOpen code has yet to run.
     * <p>
     * This state is to allow the local socket to initiate messages and frames, but to NOT start reading yet.
     */
    CONNECTED,
    /**
     * [RFC] The websocket connection is established and open.
     * <p>
     * This indicates that the Upgrade has succeed, and the end-user provided socket's onOpen code has completed.
     * <p>
     * It is now time to start reading from the remote endpoint.
     */
    OPEN,
    /**
     * [RFC] The websocket closing handshake is started.
     * <p>
     * This can be considered a half-closed state.
     * <p>
     * When receiving this as an event on {@link ConnectionStateListener#onConnectionStateChange(ConnectionState)} a close frame should be sent using
     * the {@link CloseInfo} available from {@link IOState#getCloseInfo()}
     */
    CLOSING,
    /**
     * [RFC] The websocket connection is closed.
     * <p>
     * Connection should be disconnected and no further reads or writes should occur.
     */
    CLOSED
}

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