module hunt.http.codec.websocket.model.CloseStatus;

import hunt.http.codec.websocket.model.StatusCode;

import hunt.lang.exception;

import std.conv;


class CloseStatus {
    private enum int MAX_CONTROL_PAYLOAD = 125;
    enum int MAX_REASON_PHRASE = MAX_CONTROL_PAYLOAD - 2;

    private int code;
    private string phrase;

    __gshared CloseStatus NORMAL;
    __gshared CloseStatus NO_STATUS_CODE;
    __gshared CloseStatus PROTOCOL_ERROR;

    shared static this() {
        NORMAL = new CloseStatus(StatusCode.NORMAL);
        NO_STATUS_CODE = new CloseStatus(StatusCode.NO_CODE);
        PROTOCOL_ERROR = new CloseStatus(StatusCode.PROTOCOL);
    }

    /**
     * Creates a reason for closing a web socket connection with the given code and reason phrase.
     *
     * @param closeCode    the close code
     * @param reasonPhrase the reason phrase
     * @see StatusCode
     */
    this(int closeCode, string reasonPhrase = null) {
        this.code = closeCode;
        this.phrase = reasonPhrase;
        if (reasonPhrase.length > MAX_REASON_PHRASE) {
            throw new IllegalArgumentException("Phrase exceeds maximum length of " ~ 
                MAX_REASON_PHRASE.to!string());
        }
    }

    int getCode() {
        return code;
    }

    string getPhrase() {
        return phrase;
    }
}
