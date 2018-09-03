module hunt.http.codec.websocket.frame;

import hunt.http.codec.websocket.model.OpCode;
import hunt.http.utils.StringUtils;

import hunt.container.ByteBuffer;

class PongFrame : ControlFrame {
    PongFrame() {
        super(OpCode.PONG);
    }

    PongFrame setPayload(byte[] bytes) {
        setPayload(ByteBuffer.wrap(bytes));
        return this;
    }

    PongFrame setPayload(string payload) {
        setPayload(StringUtils.getUtf8Bytes(payload));
        return this;
    }

    override
    Type getType() {
        return Type.PONG;
    }
}
