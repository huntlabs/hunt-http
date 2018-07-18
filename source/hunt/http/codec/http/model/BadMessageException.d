module hunt.http.codec.http.model.BadMessageException;

import hunt.util.exception;
import std.conv;

/**
 * <p>
 * Exception thrown to indicate a Bad HTTP Message has either been received or
 * attempted to be generated. Typically these are handled with either 400 or 500
 * responses.
 * </p>
 */
class BadMessageException :RuntimeException {
    private static long serialVersionUID = -4907256166019479626L;
    int _code;
    string _reason;

    this() {
        this(400, null);
    }

    this(int code) {
        this(code, null);
    }

    this(string reason) {
        this(400, reason);
    }

    this(int code, string reason) {
        super(to!string(code) ~ ": " ~ reason);
        _code = code;
        _reason = reason;
    }

    this(string reason, Exception cause) {
        this(400, reason, cause);
    }

    this(int code, string reason, Exception cause) {
        super(to!string(code) ~ ": " ~ reason, cause);
        _code = code;
        _reason = reason;
    }

    int getCode() {
        return _code;
    }

    string getReason() {
        return _reason;
    }
}
