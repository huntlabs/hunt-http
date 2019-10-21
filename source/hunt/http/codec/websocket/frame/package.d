module hunt.http.codec.websocket.frame;

public import hunt.http.codec.websocket.frame.BinaryFrame;
public import hunt.http.codec.websocket.frame.CloseFrame;
public import hunt.http.codec.websocket.frame.ContinuationFrame;
public import hunt.http.codec.websocket.frame.ControlFrame;
public import hunt.http.codec.websocket.frame.DataFrame;
public import hunt.http.WebSocketFrame;
public import hunt.http.codec.websocket.frame.PingFrame;
public import hunt.http.codec.websocket.frame.PongFrame;
public import hunt.http.codec.websocket.frame.ReadOnlyDelegatedFrame;
public import hunt.http.codec.websocket.frame.TextFrame;
public import hunt.http.codec.websocket.frame.AbstractWebSocketFrame;


import hunt.http.WebSocketCommon;
import hunt.collection;
import hunt.Exceptions;

import std.conv;

class WebSocketFrameHelper {
    static AbstractWebSocketFrame copy(WebSocketFrame original) {
        AbstractWebSocketFrame copy;
        switch (original.getOpCode()) {
            case OpCode.BINARY:
                copy = new BinaryFrame();
                break;
            case OpCode.TEXT:
                copy = new TextFrame();
                break;
            case OpCode.CLOSE:
                copy = new CloseFrame();
                break;
            case OpCode.CONTINUATION:
                copy = new ContinuationFrame();
                break;
            case OpCode.PING:
                copy = new PingFrame();
                break;
            case OpCode.PONG:
                copy = new PongFrame();
                break;
            default:
                throw new IllegalArgumentException("Cannot copy frame with opcode " ~ 
                    to!string(cast(int)original.getOpCode()) ~ " - " ~ (cast(Object)original).toString());
        }

        copy.copyHeaders(original);
        ByteBuffer payload = original.getPayload();
        if (payload !is null) {
            ByteBuffer payloadCopy = BufferUtils.allocate(payload.remaining());
            payloadCopy.put(payload.slice()).flip();
            copy.setPayload(payloadCopy);
        }
        return copy;
    }
}