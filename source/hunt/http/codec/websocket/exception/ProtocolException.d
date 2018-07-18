module hunt.http.codec.websocket.exception.ProtocolException;

import hunt.http.codec.websocket.model.StatusCode;
import hunt.http.codec.websocket.exception.CloseException;

/**
 * Per spec, a protocol error should result in a Close frame of status code 1002 (PROTOCOL_ERROR)
 */
class ProtocolException : CloseException {
    this(string message) {
        super(StatusCode.PROTOCOL, message);
    }

    this(string message, Throwable t) {
        super(StatusCode.PROTOCOL, message, t);
    }

    this(Throwable t) {
        super(StatusCode.PROTOCOL, t);
    }
}
