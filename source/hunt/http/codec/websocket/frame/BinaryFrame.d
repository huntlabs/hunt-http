module hunt.http.codec.websocket.frame;

import hunt.http.codec.websocket.model.OpCode;
import hunt.http.utils.StringUtils;

import hunt.container.ByteBuffer;

class BinaryFrame : DataFrame {
    this() {
        super(OpCode.BINARY);
    }

    BinaryFrame setPayload(ByteBuffer buf) {
        super.setPayload(buf);
        return this;
    }

    BinaryFrame setPayload(byte[] buf) {
        setPayload(ByteBuffer.wrap(buf));
        return this;
    }

    BinaryFrame setPayload(string payload) {
        setPayload(StringUtils.getUtf8Bytes(payload));
        return this;
    }

    override
    Type getType() {
        return getOpCode() == OpCode.CONTINUATION ? Type.CONTINUATION : Type.BINARY;
    }
}
