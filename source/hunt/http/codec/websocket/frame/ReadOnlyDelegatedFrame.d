module hunt.http.codec.websocket.frame.ReadOnlyDelegatedFrame;

import hunt.http.WebSocketFrame;
import hunt.io.ByteBuffer;

/**
 * Immutable, Read-only, WebSocketFrame implementation.
 */
class ReadOnlyDelegatedFrame : WebSocketFrame {
    private WebSocketFrame frame;

    this(WebSocketFrame frame) {
        this.frame = frame;
    }

    override
    byte[] getMask() {
        return frame.getMask();
    }

    override
    byte getOpCode() {
        return frame.getOpCode();
    }

    override
    ByteBuffer getPayload() {
        if (!frame.hasPayload()) {
            return null;
        }
        return frame.getPayload();
    }

    override
    int getPayloadLength() {
        return frame.getPayloadLength();
    }

    override
    WebSocketFrameType getType() {
        return frame.getType();
    }

    override
    bool hasPayload() {
        return frame.hasPayload();
    }

    override
    bool isFin() {
        return frame.isFin();
    }

    override
    bool isMasked() {
        return frame.isMasked();
    }

    override
    bool isRsv1() {
        return frame.isRsv1();
    }

    override
    bool isRsv2() {
        return frame.isRsv2();
    }

    override
    bool isRsv3() {
        return frame.isRsv3();
    }
}
