module hunt.http.server.Http1ServerDecoder;

import hunt.http.server.Http1ServerConnection;
import hunt.http.server.Http1ServerTunnelConnection;
import hunt.http.server.Http2ServerDecoder;

import hunt.http.codec.http.decode.HttpParser;
import hunt.http.codec.websocket.decode.WebSocketDecoder;

import hunt.http.HttpConnection;
import hunt.http.HttpConnection;
import hunt.net.codec.Decoder;
import hunt.http.HttpConnection;
import hunt.net.Connection;

import hunt.io.ByteBuffer;
import hunt.io.BufferUtils;
import hunt.Exceptions;
import hunt.logging;
import std.conv;

/**
*/
class Http1ServerDecoder : DecoderChain {

    private WebSocketDecoder webSocketDecoder;
    private Http2ServerDecoder http2ServerDecoder;

    this(WebSocketDecoder webSocketDecoder, Http2ServerDecoder http2ServerDecoder) {
        super(null);
        this.webSocketDecoder = webSocketDecoder;
        this.http2ServerDecoder = http2ServerDecoder;
    }

    override void decode(ByteBuffer buffer, Connection session) {
        ByteBuffer buf = BufferUtils.toHeapBuffer(buffer);

        Object attachment = session.getAttribute(HttpConnection.NAME);
        version (HUNT_HTTP_DEBUG) {
            tracef("session type: %s", attachment is null ? "null" : typeid(attachment).name);
        }

        AbstractHttpConnection abstractConnection = cast(AbstractHttpConnection) attachment;
        if (abstractConnection is null) {
            warningf("Bad connection instance: %s", attachment is null ? "null" : typeid(attachment).name);
            return;
        }

        switch (abstractConnection.getConnectionType()) {
        case HttpConnectionType.HTTP1: {
                Http1ServerConnection http1Connection = cast(Http1ServerConnection) attachment;
                if (http1Connection.getTunnelConnectionPromise() is null) {
                    HttpParser parser = http1Connection.getParser();
                    version (HUNT_HTTP_DEBUG) trace("runing http1 parser for a buffer...");
                    while (buf.hasRemaining()) {
                        parser.parseNext(buf);
                        if (http1Connection.getUpgradeHttp2Complete()) {
                            http2ServerDecoder.decode(buf, session);
                            break;
                        } else if (http1Connection.getUpgradeWebSocketComplete()) {
                            webSocketDecoder.decode(buf, session);
                            break;
                        }
                    }
                    version (HUNT_HTTP_DEBUG) trace("http1 parsing done for a buffer...");
                } else {
                    Http1ServerTunnelConnection tunnelConnection = http1Connection.createHttpTunnel();
                    if (tunnelConnection.content != null) {
                        tunnelConnection.content(buf);
                    }
                }
            }
            break;
        case HttpConnectionType.HTTP2: {
                http2ServerDecoder.decode(buf, session);
            }
            break;
        case HttpConnectionType.WEB_SOCKET: {
                webSocketDecoder.decode(buf, session);
            }
            break;
        case HttpConnectionType.HTTP_TUNNEL: {
                Http1ServerTunnelConnection tunnelConnection = 
                    cast(Http1ServerTunnelConnection) session.getAttribute(HttpConnection.NAME); // session.getAttachment();
                if (tunnelConnection.content != null) {
                    tunnelConnection.content(buf);
                }
            }
            break;
        default:
            throw new IllegalStateException("client does not support the protocol " ~ to!string(
                    abstractConnection.getConnectionType()));
        }
    }
}
