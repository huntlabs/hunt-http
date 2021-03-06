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

import hunt.io.ByteBuffer;
import hunt.io.channel;

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
    DataHandleStatus decode(ByteBuffer buffer, Connection session) {
        ByteBuffer buf = buffer; // toHeapBuffer(buffer);
        Object attachment = session.getAttribute(HttpConnection.NAME); // session.getAttachment();
        DataHandleStatus resultStatus = DataHandleStatus.Done;

        AbstractHttpConnection abstractConnection = cast(AbstractHttpConnection) attachment;
        if(abstractConnection is null) {
            throw new IllegalStateException("Client connection is null! The actual type is: " 
                ~ typeid(attachment).name);
        }

        switch (abstractConnection.getConnectionType()) {
            case HttpConnectionType.HTTP1: {
                Http1ClientConnection http1Connection = cast(Http1ClientConnection) abstractConnection;
                HttpParser parser = http1Connection.getParser();
                while (buf.hasRemaining()) {
                    version(HUNT_HTTP_DEBUG) tracef("parsing buffer: %s", buf.toString());
                    parser.parseNext(buf);
                    if (http1Connection.getUpgradeHttp2Complete()) {
                        resultStatus = http2ClientDecoder.decode(buf, session);
                        break;
                    } else if (http1Connection.getUpgradeWebSocketComplete()) {
                        resultStatus = webSocketDecoder.decode(buf, session);
                        break;
                    }
                }
            }
            break;

            case HttpConnectionType.HTTP2: {
                resultStatus = http2ClientDecoder.decode(buf, session);
            }
            break;

            case HttpConnectionType.WEB_SOCKET: {
                resultStatus = webSocketDecoder.decode(buf, session);
            }
            break;

            default:
                string msg = "client does not support the protocol " ~ abstractConnection.getConnectionType().to!string();
                error(msg);
                throw new IllegalStateException(msg);
        }

        return resultStatus;
    }

}
