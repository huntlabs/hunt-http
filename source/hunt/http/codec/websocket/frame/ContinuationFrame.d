module hunt.http.codec.websocket.frame.ContinuationFrame;

import hunt.http.codec.websocket.frame.DataFrame;
import hunt.http.codec.websocket.frame.Frame;
import hunt.http.codec.websocket.model.common;

import hunt.collection.BufferUtils;
import hunt.collection.ByteBuffer;

class ContinuationFrame : DataFrame {
    this() {
        super(OpCode.CONTINUATION);
    }

    override ContinuationFrame setPayload(ByteBuffer buf) {
        super.setPayload(buf);
        return this;
    }

    ContinuationFrame setPayload(byte[] buf) {
        return this.setPayload(BufferUtils.toBuffer(buf));
    }

    ContinuationFrame setPayload(string message) {
        return this.setPayload(cast(byte[])(message.dup));
    }

    override
    WebSocketFrameType getType() {
        return WebSocketFrameType.CONTINUATION;
    }
}
