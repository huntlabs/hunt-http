module hunt.http.client.Http1ClientDecoder;

import hunt.http.client.Http1ClientConnection;
import hunt.http.client.Http2ClientDecoder;

import hunt.http.codec.http.decode.HttpParser;
import hunt.http.codec.websocket.decode.WebSocketDecoder;

import hunt.http.HttpConnection;
import hunt.http.HttpConnection;
import hunt.http.HttpConnection;
import hunt.net.codec.Decoder;
import hunt.net.Connection;

import hunt.Exceptions;

import hunt.collection.ByteBuffer;

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
    void decode(ByteBuffer buffer, Connection session) {
        ByteBuffer buf = buffer; // toHeapBuffer(buffer);
        Object attachment = session.getAttribute(HttpConnection.NAME); // session.getAttachment();

        AbstractHttpConnection abstractConnection = cast(AbstractHttpConnection) attachment;
        if(abstractConnection is null)
        {
            throw new IllegalStateException("Client connection is null! The actual type is: " 
                ~ typeid(attachment).name);
        }

        switch (abstractConnection.getConnectionType()) {
            case HttpConnectionType.HTTP1: {
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

            case HttpConnectionType.HTTP2: {
                http2ClientDecoder.decode(buf, session);
            }
            break;

            case HttpConnectionType.WEB_SOCKET: {
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
