module hunt.http.codec.websocket.frame;

import hunt.http.codec.websocket.model.OpCode;
import hunt.http.utils.StringUtils;
import hunt.http.utils.io.BufferUtils;

import hunt.container.ByteBuffer;

class TextFrame : DataFrame {
    TextFrame() {
        super(OpCode.TEXT);
    }

    override
    Type getType() {
        return getOpCode() == OpCode.CONTINUATION ? Type.CONTINUATION : Type.TEXT;
    }

    TextFrame setPayload(string str) {
        setPayload(ByteBuffer.wrap(StringUtils.getUtf8Bytes(str)));
        return this;
    }

    string getPayloadAsUTF8() {
        if (data == null) {
            return null;
        }
        return BufferUtils.toUTF8String(data);
    }
}
