module hunt.http.codec.websocket.frame.BinaryFrame;

import hunt.http.codec.websocket.frame.DataFrame;
import hunt.http.codec.websocket.model.common;

import hunt.collection.BufferUtils;
import hunt.collection.ByteBuffer;

class BinaryFrame : DataFrame {
    this() {
        super(OpCode.BINARY);
    }

    override BinaryFrame setPayload(ByteBuffer buf) {
        super.setPayload(buf);
        return this;
    }

    BinaryFrame setPayload(byte[] buf) {
        setPayload(BufferUtils.toBuffer(buf));
        return this;
    }

    BinaryFrame setPayload(string payload) {
        setPayload(cast(byte[])(payload.dup));
        return this;
    }

    override
    Type getType() {
        return getOpCode() == OpCode.CONTINUATION ? Type.CONTINUATION : Type.BINARY;
    }
}
