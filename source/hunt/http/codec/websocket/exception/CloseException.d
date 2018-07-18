module hunt.http.codec.websocket.exception.CloseException;

import hunt.http.codec.websocket.exception.WebSocketException;

class CloseException : WebSocketException {
    private int statusCode;

    this(int closeCode, string message) {
        super(message);
        this.statusCode = closeCode;
    }

    this(int closeCode, string message, Throwable cause) {
        super(message, cause);
        this.statusCode = closeCode;
    }

    this(int closeCode, Throwable cause) {
        super(cause);
        this.statusCode = closeCode;
    }

    int getStatusCode() {
        return statusCode;
    }

}
