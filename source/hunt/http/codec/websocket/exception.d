module hunt.http.codec.websocket.exception;

import hunt.http.codec.websocket.model.StatusCode;
import hunt.util.exception;


class WebSocketException : RuntimeException
{
    mixin BasicExceptionCtors;
}

class CloseException : WebSocketException
{
    private int statusCode;

    this(int closeCode, string message, size_t line = __LINE__, string file = __FILE__) {
        super(message);
        this.statusCode = closeCode;
    }

    this(int closeCode, string message, Throwable cause, size_t line = __LINE__, string file = __FILE__) {
        super(message, cause);
        this.statusCode = closeCode;
    }

    this(int closeCode, Throwable cause, size_t line = __LINE__, string file = __FILE__) {
        super(cause);
        this.statusCode = closeCode;
    }

    int getStatusCode() {
        return statusCode;
    }

}

class BadPayloadException : CloseException
{    
    this(string message, size_t line = __LINE__, string file = __FILE__) {
        super(StatusCode.BAD_PAYLOAD, message, line, file);
    }

    this(string message, Throwable t, size_t line = __LINE__, string file = __FILE__) {
        super(StatusCode.BAD_PAYLOAD, message, t, line, file);
    }

    this(Throwable t, size_t line = __LINE__, string file = __FILE__) {
        super(StatusCode.BAD_PAYLOAD, t, line, file);
    }
}

class MessageTooLargeException : CloseException
{
    this(string message, size_t line = __LINE__, string file = __FILE__) {
        super(StatusCode.MESSAGE_TOO_LARGE, message, line, file);
    }

    this(string message, Throwable t, size_t line = __LINE__, string file = __FILE__) {
        super(StatusCode.MESSAGE_TOO_LARGE, message, t, line, file);
    }

    this(Throwable t, size_t line = __LINE__, string file = __FILE__) {
        super(StatusCode.MESSAGE_TOO_LARGE, t, line, file);
    }
}

class ProtocolException : CloseException
{
    this(string message, size_t line = __LINE__, string file = __FILE__) {
        super(StatusCode.PROTOCOL, message, line, file);
    }

    this(string message, Throwable t, size_t line = __LINE__, string file = __FILE__) {
        super(StatusCode.PROTOCOL, message, t, line, file);
    }

    this(Throwable t, size_t line = __LINE__, string file = __FILE__) {
        super(StatusCode.PROTOCOL, t, line, file);
    }
}