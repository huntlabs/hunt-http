module hunt.http.codec.websocket.frame.PongFrame;

import hunt.http.WebSocketFrame;
import hunt.http.codec.websocket.frame.ControlFrame;
import hunt.http.WebSocketCommon;
import hunt.text.Common;

import hunt.io.BufferUtils;
import hunt.io.ByteBuffer;

class PongFrame : ControlFrame {
    this() {
        super(OpCode.PONG);
    }

    PongFrame setPayload(byte[] bytes) {
        setPayload(BufferUtils.toBuffer(bytes));
        return this;
    }

    PongFrame setPayload(string payload) {
        setPayload(cast(byte[])(payload.dup));
        return this;
    }

    alias setPayload = ControlFrame.setPayload;

    override
    WebSocketFrameType getType() {
        return WebSocketFrameType.PONG;
    }
}
