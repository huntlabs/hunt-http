module hunt.http.codec.websocket.frame;

import hunt.http.codec.websocket.model.OpCode;
import hunt.http.utils.StringUtils;

import hunt.container.ByteBuffer;

class PingFrame : ControlFrame {
    PingFrame() {
        super(OpCode.PING);
    }

    PingFrame setPayload(byte[] bytes) {
        setPayload(ByteBuffer.wrap(bytes));
        return this;
    }

    PingFrame setPayload(string payload) {
        setPayload(ByteBuffer.wrap(StringUtils.getUtf8Bytes(payload)));
        return this;
    }

    override
    Type getType() {
        return Type.PING;
    }
}
