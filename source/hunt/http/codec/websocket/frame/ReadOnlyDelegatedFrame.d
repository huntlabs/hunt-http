module hunt.http.codec.websocket.frame.ReadOnlyDelegatedFrame;

import hunt.http.codec.websocket.frame.Frame;
import hunt.collection.ByteBuffer;

/**
 * Immutable, Read-only, Frame implementation.
 */
class ReadOnlyDelegatedFrame : Frame {
    private Frame frame;

    this(Frame frame) {
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
    Type getType() {
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
