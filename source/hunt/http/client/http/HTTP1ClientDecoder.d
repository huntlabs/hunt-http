module hunt.http.client.http.HTTP1ClientDecoder;

import hunt.http.client.http.HTTP1ClientConnection;
import hunt.http.client.http.HTTP2ClientDecoder;

import hunt.http.codec.http.decode.HttpParser;
import hunt.http.codec.websocket.decode.WebSocketDecoder;

import hunt.net.AbstractConnection;
import hunt.net.ConnectionType;
import hunt.net.DecoderChain;
import hunt.net.Session;

import hunt.util.exception;

import hunt.container.ByteBuffer;

import kiss.logger;
import std.conv;


// import hunt.http.utils.io.BufferUtils.toHeapBuffer;

class HTTP1ClientDecoder : DecoderChain {

    // private WebSocketDecoder webSocketDecoder;
    private HTTP2ClientDecoder http2ClientDecoder;

    this(HTTP2ClientDecoder http2ClientDecoder) { // WebSocketDecoder webSocketDecoder,
        super(null);
        // this.webSocketDecoder = webSocketDecoder;
        this.http2ClientDecoder = http2ClientDecoder;
    }

    override
    void decode(ByteBuffer buffer, Session session) {
        ByteBuffer buf = buffer; // toHeapBuffer(buffer);
        Object attachment = session.getAttachment();
        AbstractConnection abstractConnection = cast(AbstractConnection) session.getAttachment();
        if(abstractConnection is null)
        {
            throw new IllegalStateException("Client connection is null! The actual type is: " 
                ~ typeid(attachment).name);
        }

        switch (abstractConnection.getConnectionType()) {
            case ConnectionType.HTTP1: {
                HTTP1ClientConnection http1Connection = cast(HTTP1ClientConnection) abstractConnection;
                HttpParser parser = http1Connection.getParser();
                while (buf.hasRemaining()) {
                    parser.parseNext(buf);
                    if (http1Connection.getUpgradeHTTP2Complete()) {
                        http2ClientDecoder.decode(buf, session);
                        break;
                    // } else if (http1Connection.getUpgradeWebSocketComplete()) {
                    //     webSocketDecoder.decode(buf, session);
                    //     break;
                    }
                }
            }
            break;
            case ConnectionType.HTTP2: {
                http2ClientDecoder.decode(buf, session);
            }
            break;
            // case ConnectionType.WEB_SOCKET: {
            //     webSocketDecoder.decode(buf, session);
            // }
            // break;
            default:
                throw new IllegalStateException("client does not support the protocol " ~ abstractConnection.getConnectionType().to!string());
        }
    }

}
