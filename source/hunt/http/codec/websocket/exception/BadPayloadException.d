module hunt.http.codec.websocket.exception.BadPayloadException;

import hunt.http.codec.websocket.exception.CloseException;
import hunt.http.codec.websocket.model.StatusCode;

/**
 * Exception to terminate the connection because it has received data within a frame payload that was not consistent with the requirements of that frame
 * payload. (eg: not UTF-8 in a text frame, or a unexpected data seen by an extension)
 *
 * @see StatusCode#BAD_PAYLOAD
 */
class BadPayloadException : CloseException {
    this(string message) {
        super(StatusCode.BAD_PAYLOAD, message);
    }

    this(string message, Throwable t) {
        super(StatusCode.BAD_PAYLOAD, message, t);
    }

    this(Throwable t) {
        super(StatusCode.BAD_PAYLOAD, t);
    }
}
