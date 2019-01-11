module hunt.http.codec.websocket.frame.PongFrame;

import hunt.http.codec.websocket.frame.Frame;
import hunt.http.codec.websocket.frame.ControlFrame;
import hunt.http.codec.websocket.model.common;
import hunt.text.Common;

import hunt.collection.ByteBuffer;

class PongFrame : ControlFrame {
    this() {
        super(OpCode.PONG);
    }

    PongFrame setPayload(byte[] bytes) {
        setPayload(ByteBuffer.wrap(bytes));
        return this;
    }

    PongFrame setPayload(string payload) {
        setPayload(cast(byte[])(payload.dup));
        return this;
    }

    alias setPayload = ControlFrame.setPayload;

    override
    Type getType() {
        return Type.PONG;
    }
}
