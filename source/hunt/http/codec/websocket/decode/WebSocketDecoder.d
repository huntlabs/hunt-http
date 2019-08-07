module hunt.http.codec.websocket.decode.WebSocketDecoder;

import hunt.http.HttpConnection;
import hunt.http.codec.websocket.stream.WebSocketConnectionImpl;

import hunt.net.codec.Decoder;
import hunt.net.Connection;

import hunt.collection.ByteBuffer;

/**
 * 
 */
class WebSocketDecoder : DecoderChain {

    this() {
        super(null);
    }

    override
    void decode(ByteBuffer buffer, Connection session) {
        if (!buffer.hasRemaining()) {
            return;
        }

        WebSocketConnectionImpl webSocketConnection = cast(WebSocketConnectionImpl) session.getAttribute(HttpConnection.NAME); // session.getAttachment();
        while (buffer.hasRemaining()) {
            webSocketConnection.getParser().parse(buffer);
        }
    }
}
