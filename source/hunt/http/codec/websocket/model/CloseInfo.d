module hunt.http.codec.websocket.model.CloseInfo;

import hunt.http.codec.websocket.model.CloseStatus;
import hunt.http.WebSocketStatusCode;

import hunt.http.Exceptions;
import hunt.http.codec.websocket.frame.CloseFrame;
import hunt.http.WebSocketFrame;

import hunt.io.BufferUtils;
import hunt.io.ByteBuffer;

import std.algorithm;
import std.conv;
import std.format;
import std.utf;

/**
*/
class CloseInfo {
    private int statusCode = 0;
    private byte[] reasonBytes;

    this() {
        this(StatusCode.NO_CODE, null);
    }

    /**
     * Parse the Close WebSocketFrame payload.
     *
     * @param payload  the raw close frame payload.
     * @param validate true if payload should be validated per WebSocket spec.
     */
    this(ByteBuffer payload, bool validate) {
        this.statusCode = StatusCode.NO_CODE;

        if ((payload is null) || (payload.remaining() == 0)) {
            return; // nothing to do
        }

        ByteBuffer data = payload.slice();
        if ((data.remaining() == 1) && (validate)) {
            throw new ProtocolException("Invalid 1 byte payload");
        }

        if (data.remaining() >= 2) {
            // Status Code
            statusCode = 0; // start with 0
            statusCode |= (data.get() & 0xFF) << 8;
            statusCode |= (data.get() & 0xFF);

            if (validate) {
                assertValidStatusCode(statusCode);
            }

            if (data.remaining() > 0) {
                // Reason (trimmed to max reason size)
                int len = std.algorithm.min(data.remaining(), CloseStatus.MAX_REASON_PHRASE);
                reasonBytes = new byte[len];
                data.get(reasonBytes, 0, len);

                // Spec Requirement : throw BadPayloadException on invalid UTF8
                if (validate) {
                    try {
                        // Utf8StringBuilder utf = new Utf8StringBuilder();
                        // // if this throws, we know we have bad UTF8
                        // utf.append(reasonBytes, 0, reasonBytes.length);
                        std.utf.validate(cast(string)reasonBytes);
                    } catch (UTFException e) {
                        throw new BadPayloadException("Invalid Close Reason", e);
                    }
                }
            }
        }
    }

    this(WebSocketFrame frame) {
        this(frame.getPayload(), false);
    }

    this(WebSocketFrame frame, bool validate) {
        this(frame.getPayload(), validate);
    }

    this(int statusCode) {
        this(statusCode, null);
    }

    /**
     * Create a CloseInfo, trimming the reason to {@link CloseStatus#MAX_REASON_PHRASE} UTF-8 bytes if needed.
     *
     * @param statusCode the status code
     * @param reason     the raw reason code
     */
    this(int statusCode, string reason) {
        this.statusCode = statusCode;
        if (reason !is null) {            
            int len = CloseStatus.MAX_REASON_PHRASE;
            if (reason.length > len) {
                this.reasonBytes = cast(byte[])reason[0..len].dup;
            } else {
                this.reasonBytes = cast(byte[])reason.dup;
            }
        }
    }

    private void assertValidStatusCode(int statusCode) {
        // Status Codes outside of RFC6455 defined scope
        if ((statusCode <= 999) || (statusCode >= 5000)) {
            throw new ProtocolException("Out of range close status code: " ~ statusCode.to!string());
        }

        // Status Codes not allowed to exist in a Close frame (per RFC6455)
        if ((statusCode == StatusCode.NO_CLOSE) || 
            (statusCode == StatusCode.NO_CODE) || 
            (statusCode == StatusCode.FAILED_TLS_HANDSHAKE)) {
            throw new ProtocolException("WebSocketFrame forbidden close status code: " ~ statusCode.to!string());
        }

        // Status Code is in defined "reserved space" and is declared (all others are invalid)
        if ((statusCode >= 1000) && (statusCode <= 2999) && !StatusCode.isTransmittable(statusCode)) {
            throw new ProtocolException("RFC6455 and IANA Undefined close status code: " ~ statusCode.to!string());
        }
    }

    private ByteBuffer asByteBuffer() {
        if ((statusCode == StatusCode.NO_CLOSE) || (statusCode == StatusCode.NO_CODE) || (statusCode == (-1))) {
            // codes that are not allowed to be used in endpoint.
            return null;
        }

        int len = 2; // status code
        bool hasReason = (this.reasonBytes !is null) && (this.reasonBytes.length > 0);
        if (hasReason) {
            len += this.reasonBytes.length;
        }

        ByteBuffer buf = BufferUtils.allocate(len);
        BufferUtils.flipToFill(buf);
        buf.put(cast(byte) ((statusCode >>> 8) & 0xFF));
        buf.put(cast(byte) ((statusCode >>> 0) & 0xFF));

        if (hasReason) {
            buf.put(this.reasonBytes, 0, cast(int)this.reasonBytes.length);
        }
        BufferUtils.flipToFlush(buf, 0);

        return buf;
    }

    CloseFrame asFrame() {
        CloseFrame frame = new CloseFrame();
        frame.setFin(true);
        // WebSocketFrame forbidden codes result in no status code (and no reason string)
        if ((statusCode != StatusCode.NO_CLOSE) && (statusCode != StatusCode.NO_CODE) && 
                (statusCode != StatusCode.FAILED_TLS_HANDSHAKE)) {
            assertValidStatusCode(statusCode);
            frame.setPayload(asByteBuffer());
        }
        return frame;
    }

    string getReason() {
        if (this.reasonBytes is null) {
            return null;
        }
        return cast(string)(this.reasonBytes);
    }

    int getStatusCode() {
        return statusCode;
    }

    bool isHarsh() {
        return !((statusCode == StatusCode.NORMAL) || (statusCode == StatusCode.NO_CODE));
    }

    bool isAbnormal() {
        return (statusCode != StatusCode.NORMAL);
    }

    override
    string toString() {
        return format("CloseInfo[code=%d,reason=%s]", statusCode, getReason());
    }
}
