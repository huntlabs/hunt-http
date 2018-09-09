module hunt.http.codec.websocket.decode.WebSocketDecoder;

import hunt.http.codec.websocket.stream.WebSocketConnectionImpl;

import hunt.net.DecoderChain;
import hunt.net.Session;

import hunt.container.ByteBuffer;

/**
 * 
 */
class WebSocketDecoder : DecoderChain {

    this() {
        super(null);
    }

    override
    void decode(ByteBuffer buffer, Session session) {
        if (!buffer.hasRemaining()) {
            return;
        }

        WebSocketConnectionImpl webSocketConnection = cast(WebSocketConnectionImpl) session.getAttachment();
        while (buffer.hasRemaining()) {
            webSocketConnection.getParser().parse(buffer);
        }
    }
}
