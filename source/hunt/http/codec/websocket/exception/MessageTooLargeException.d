module hunt.http.codec.websocket.exception.MessageTooLargeException;

import hunt.http.codec.websocket.model.StatusCode;
import hunt.http.codec.websocket.exception.CloseException;

/**
 * Exception when a message is too large for the internal buffers occurs and should trigger a connection close.
 *
 * @see StatusCode#MESSAGE_TOO_LARGE
 */
class MessageTooLargeException : CloseException {
    this(string message) {
        super(StatusCode.MESSAGE_TOO_LARGE, message);
    }

    this(string message, Throwable t) {
        super(StatusCode.MESSAGE_TOO_LARGE, message, t);
    }

    this(Throwable t) {
        super(StatusCode.MESSAGE_TOO_LARGE, t);
    }
}
