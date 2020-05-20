module hunt.http.codec.websocket.frame.TextFrame;

import hunt.http.codec.websocket.frame.DataFrame;
import hunt.http.codec.websocket.frame.AbstractWebSocketFrame;
import hunt.http.WebSocketCommon;
import hunt.http.WebSocketFrame;


import hunt.io.ByteBuffer;
import hunt.io.BufferUtils;
import hunt.text.Common;

class TextFrame : DataFrame {
    this() {
        super(OpCode.TEXT);
    }

    override
    WebSocketFrameType getType() {
        return getOpCode() == OpCode.CONTINUATION ? WebSocketFrameType.CONTINUATION : WebSocketFrameType.TEXT;
    }

    TextFrame setPayload(string str) {
        // FIXME: Needing refactor or cleanup -@zhangxueping at 2019-10-19T13:14:09+08:00
        // copy or not?
        setPayload(BufferUtils.toBuffer(cast(byte[])(str.dup)));
        return this;
    }

    alias setPayload = AbstractWebSocketFrame.setPayload;

    override string getPayloadAsUTF8() {
        if (data is null) {
            return null;
        }
        return BufferUtils.toString(data);
    }
}
