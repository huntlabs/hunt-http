module hunt.http.codec.websocket.frame;

import hunt.container.ByteBuffer;

/**
 * Immutable, Read-only, Frame implementation.
 */
class ReadOnlyDelegatedFrame : Frame {
    private final Frame dg;

    this(Frame frame) {
        this.dg = frame;
    }

    override
    byte[] getMask() {
        return dg.getMask();
    }

    override
    byte getOpCode() {
        return dg.getOpCode();
    }

    override
    ByteBuffer getPayload() {
        if (!dg.hasPayload()) {
            return null;
        }
        return dg.getPayload().asReadOnlyBuffer();
    }

    override
    int getPayloadLength() {
        return dg.getPayloadLength();
    }

    override
    Type getType() {
        return dg.getType();
    }

    override
    bool hasPayload() {
        return dg.hasPayload();
    }

    override
    bool isFin() {
        return dg.isFin();
    }

    override
    bool isMasked() {
        return dg.isMasked();
    }

    override
    bool isRsv1() {
        return dg.isRsv1();
    }

    override
    bool isRsv2() {
        return dg.isRsv2();
    }

    override
    bool isRsv3() {
        return dg.isRsv3();
    }
}
