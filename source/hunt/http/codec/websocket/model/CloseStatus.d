module hunt.http.codec.websocket.model.CloseStatus;

import hunt.http.codec.websocket.model.StatusCode;

import hunt.lang.exception;

import std.conv;


class CloseStatus {
    private enum int MAX_CONTROL_PAYLOAD = 125;
    enum int MAX_REASON_PHRASE = MAX_CONTROL_PAYLOAD - 2;

    __gshared CloseStatus NORMAL;
    __gshared CloseStatus NO_STATUS_CODE;
    __gshared CloseStatus PROTOCOL_ERROR;

    shared static this() {
        NORMAL = new CloseStatus(StatusCode.NORMAL);
        NO_STATUS_CODE = new CloseStatus(StatusCode.NO_CODE);
        PROTOCOL_ERROR = new CloseStatus(StatusCode.PROTOCOL);
    }

    /**
     * Convenience method for trimming a long reason phrase at the maximum reason phrase length of 123 UTF-8 bytes (per WebSocket spec).
     *
     * @param reason the proposed reason phrase
     * @return the reason phrase (trimmed if needed)
     * @deprecated use of this method is strongly discouraged, as it creates too many new objects that are just thrown away to accomplish its goals.
     */
    deprecated("")
    static string trimMaxReasonLength(string reason) {
        if (reason is null) {
            return null;
        }

        // byte[] reasonBytes = reason.getBytes(StandardCharsets.UTF_8);
        // if (reasonBytes.length > MAX_REASON_PHRASE) {
        //     byte[] trimmed = reasonBytes[0..MAX_REASON_PHRASE];
        //     // System.arraycopy(reasonBytes, 0, trimmed, 0, MAX_REASON_PHRASE);
        //     return new string(trimmed, StandardCharsets.UTF_8);
        // }

        return reason;
    }

    private int code;
    private string phrase;

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
