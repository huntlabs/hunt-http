module hunt.http.client.Http1ClientDecoder;

import hunt.http.client.Http1ClientConnection;
import hunt.http.client.Http2ClientDecoder;

import hunt.http.codec.http.decode.HttpParser;
import hunt.http.codec.websocket.decode.WebSocketDecoder;

import hunt.net.AbstractConnection;
import hunt.net.ConnectionType;
import hunt.net.DecoderChain;
import hunt.net.Session;

import hunt.lang.exception;

import hunt.container.ByteBuffer;

import hunt.logging;
import std.conv;


// import hunt.http.utils.io.BufferUtils.toHeapBuffer;

class Http1ClientDecoder : DecoderChain {

    private WebSocketDecoder webSocketDecoder;
    private Http2ClientDecoder http2ClientDecoder;

    this(WebSocketDecoder webSocketDecoder, Http2ClientDecoder http2ClientDecoder) {
        super(null);
        this.webSocketDecoder = webSocketDecoder;
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
                Http1ClientConnection http1Connection = cast(Http1ClientConnection) abstractConnection;
                HttpParser parser = http1Connection.getParser();
                while (buf.hasRemaining()) {
                    parser.parseNext(buf);
                    if (http1Connection.getUpgradeHttp2Complete()) {
                        http2ClientDecoder.decode(buf, session);
                        break;
                    } else if (http1Connection.getUpgradeWebSocketComplete()) {
                        webSocketDecoder.decode(buf, session);
                        break;
                    }
                }
            }
            break;

            case ConnectionType.HTTP2: {
                http2ClientDecoder.decode(buf, session);
            }
            break;

            case ConnectionType.WEB_SOCKET: {
                webSocketDecoder.decode(buf, session);
            }
            break;

            default:
                string msg = "client does not support the protocol " ~ abstractConnection.getConnectionType().to!string();
                error(msg);
                throw new IllegalStateException(msg);
        }
    }

}
