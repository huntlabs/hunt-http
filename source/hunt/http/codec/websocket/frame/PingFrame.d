module hunt.http.codec.websocket.frame.PingFrame;

import hunt.http.WebSocketFrame;
import hunt.http.codec.websocket.frame.ControlFrame;
import hunt.http.WebSocketCommon;

import hunt.text.Common;
import hunt.io.BufferUtils;
import hunt.io.ByteBuffer;

class PingFrame : ControlFrame {
    this() {
        super(OpCode.PING);
    }

    PingFrame setPayload(byte[] bytes) {
        setPayload(BufferUtils.toBuffer(bytes));
        return this;
    }

    PingFrame setPayload(string payload) {
        setPayload(BufferUtils.toBuffer(cast(byte[])(payload.dup)));
        return this;
    }

    alias setPayload = ControlFrame.setPayload;

    override
    WebSocketFrameType getType() {
        return WebSocketFrameType.PING;
    }
}
