module hunt.http.codec.websocket.frame.ContinuationFrame;

import hunt.http.codec.websocket.frame.DataFrame;
import hunt.http.WebSocketFrame;
import hunt.http.WebSocketCommon;

import hunt.io.BufferUtils;
import hunt.io.ByteBuffer;

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
