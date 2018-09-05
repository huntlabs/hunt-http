module hunt.http.codec.websocket.frame.ContinuationFrame;

import hunt.http.codec.websocket.frame.DataFrame;
import hunt.http.codec.websocket.model.common;

import hunt.container.ByteBuffer;

class ContinuationFrame : DataFrame {
    this() {
        super(OpCode.CONTINUATION);
    }

    override ContinuationFrame setPayload(ByteBuffer buf) {
        super.setPayload(buf);
        return this;
    }

    ContinuationFrame setPayload(byte[] buf) {
        return this.setPayload(ByteBuffer.wrap(buf));
    }

    ContinuationFrame setPayload(string message) {
        return this.setPayload(cast(byte[])(message));
    }

    override
    Type getType() {
        return Type.CONTINUATION;
    }
}
