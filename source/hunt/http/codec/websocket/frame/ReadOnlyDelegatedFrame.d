module hunt.http.codec.websocket.frame;

import hunt.container.ByteBuffer;

/**
 * Immutable, Read-only, Frame implementation.
 */
class ReadOnlyDelegatedFrame : Frame {
    private final Frame delegate;

    ReadOnlyDelegatedFrame(Frame frame) {
        this.delegate = frame;
    }

    override
    byte[] getMask() {
        return delegate.getMask();
    }

    override
    byte getOpCode() {
        return delegate.getOpCode();
    }

    override
    ByteBuffer getPayload() {
        if (!delegate.hasPayload()) {
            return null;
        }
        return delegate.getPayload().asReadOnlyBuffer();
    }

    override
    int getPayloadLength() {
        return delegate.getPayloadLength();
    }

    override
    Type getType() {
        return delegate.getType();
    }

    override
    bool hasPayload() {
        return delegate.hasPayload();
    }

    override
    bool isFin() {
        return delegate.isFin();
    }

    override
    bool isMasked() {
        return delegate.isMasked();
    }

    override
    bool isRsv1() {
        return delegate.isRsv1();
    }

    override
    bool isRsv2() {
        return delegate.isRsv2();
    }

    override
    bool isRsv3() {
        return delegate.isRsv3();
    }
}
