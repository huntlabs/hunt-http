module hunt.http.codec.websocket.exception.WebSocketException;

import hunt.util.exception;

/**
 * A recoverable exception within the websocket framework.
 */
class WebSocketException : RuntimeException {
    this() {
        super("");
    }

    this(string message) {
        super(message);
    }

    this(string message, Throwable cause) {
        super(message, cause);
    }

    this(Throwable cause) {
        super("", cause);
    }
}
