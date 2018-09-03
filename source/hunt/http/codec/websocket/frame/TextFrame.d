module hunt.http.codec.websocket.frame;

import hunt.http.codec.websocket.model.OpCode;
import hunt.http.utils.StringUtils;
import hunt.http.utils.io.BufferUtils;

import hunt.container.ByteBuffer;
import hunt.container.BufferUtils;

class TextFrame : DataFrame {
    this() {
        super(OpCode.TEXT);
    }

    override
    Type getType() {
        return getOpCode() == OpCode.CONTINUATION ? Type.CONTINUATION : Type.TEXT;
    }

    TextFrame setPayload(string str) {
        setPayload(ByteBuffer.wrap(cast(byte[])(str)));
        return this;
    }

    string getPayloadAsUTF8() {
        if (data is null) {
            return null;
        }
        return BufferUtils.toString(data);
    }
}
