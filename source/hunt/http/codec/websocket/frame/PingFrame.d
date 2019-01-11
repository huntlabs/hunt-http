module hunt.http.codec.websocket.frame.PingFrame;

import hunt.http.codec.websocket.frame.Frame;
import hunt.http.codec.websocket.frame.ControlFrame;
import hunt.http.codec.websocket.model.common;

import hunt.text.Common;
import hunt.collection.ByteBuffer;

class PingFrame : ControlFrame {
    this() {
        super(OpCode.PING);
    }

    PingFrame setPayload(byte[] bytes) {
        setPayload(ByteBuffer.wrap(bytes));
        return this;
    }

    PingFrame setPayload(string payload) {
        setPayload(ByteBuffer.wrap(cast(byte[])(payload.dup)));
        return this;
    }

    alias setPayload = ControlFrame.setPayload;

    override
    Type getType() {
        return Type.PING;
    }
}
