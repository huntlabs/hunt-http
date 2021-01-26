module hunt.http.codec.websocket.decode.WebSocketDecoder;

import hunt.http.HttpConnection;
import hunt.http.codec.websocket.stream.WebSocketConnectionImpl;

import hunt.net.codec.Decoder;
import hunt.net.Connection;

import hunt.io.ByteBuffer;
import hunt.io.channel;

/**
 * 
 */
class WebSocketDecoder : DecoderChain {

    this() {
        super(null);
    }

    override
    DataHandleStatus decode(ByteBuffer buffer, Connection session) {

        if (!buffer.hasRemaining()) {
            return DataHandleStatus.Done;
        }

        WebSocketConnectionImpl webSocketConnection = cast(WebSocketConnectionImpl) session.getAttribute(HttpConnection.NAME); // session.getAttachment();
        while (buffer.hasRemaining()) {
            webSocketConnection.getParser().parse(buffer);
        }
        
        return DataHandleStatus.Done;
    }
}
