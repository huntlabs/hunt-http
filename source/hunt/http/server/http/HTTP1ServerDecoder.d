module hunt.http.server.http.HTTP1ServerDecoder;

import hunt.http.server.http.HTTP1ServerConnection;
import hunt.http.server.http.HTTP1ServerTunnelConnection;
import hunt.http.server.http.HTTP2ServerDecoder;


import hunt.http.codec.http.decode.HttpParser;
import hunt.http.codec.websocket.decode.WebSocketDecoder;

import hunt.net.AbstractConnection;
import hunt.net.DecoderChain;
import hunt.net.ConnectionType;
import hunt.net.Session;

import hunt.container.ByteBuffer;
import hunt.container.BufferUtils;

import hunt.util.exception;

import std.conv;

class HTTP1ServerDecoder : DecoderChain {

    private  WebSocketDecoder webSocketDecoder;
    private  HTTP2ServerDecoder http2ServerDecoder;

    this(WebSocketDecoder webSocketDecoder, HTTP2ServerDecoder http2ServerDecoder) {
        super(null);
        this.webSocketDecoder = webSocketDecoder;
        this.http2ServerDecoder = http2ServerDecoder;
    }


    override
    void decode(ByteBuffer buffer, Session session) {
        ByteBuffer buf = BufferUtils.toHeapBuffer(buffer);
        AbstractConnection abstractConnection = cast(AbstractConnection) session.getAttachment();
        switch (abstractConnection.getConnectionType()) {
            case ConnectionType.HTTP1: {
                 HTTP1ServerConnection http1Connection = cast(HTTP1ServerConnection) session.getAttachment();
                if (http1Connection.getTunnelConnectionPromise() is null) {
                     HttpParser parser = http1Connection.getParser();
                    while (buf.hasRemaining()) {
                        parser.parseNext(buf);
                        if (http1Connection.getUpgradeHTTP2Complete()) {
                            http2ServerDecoder.decode(buf, session);
                            break;
                        } else if (http1Connection.getUpgradeWebSocketComplete()) {
                            webSocketDecoder.decode(buf, session);
                            break;
                        }
                    }
                } else {
                    HTTP1ServerTunnelConnection tunnelConnection = http1Connection.createHTTPTunnel();
                    if (tunnelConnection.content != null) {
                        tunnelConnection.content(buf);
                    }
                }
            }
            break;
            case ConnectionType.HTTP2: {
                http2ServerDecoder.decode(buf, session);
            }
            break;
            case ConnectionType.WEB_SOCKET: {
                webSocketDecoder.decode(buf, session);
            }
            break;
            case ConnectionType.HTTP_TUNNEL: {
                HTTP1ServerTunnelConnection tunnelConnection = cast(HTTP1ServerTunnelConnection) session.getAttachment();
                if (tunnelConnection.content != null) {
                    tunnelConnection.content(buf);
                }
            }
            break;
            default:
                throw new IllegalStateException("client does not support the protocol " ~ to!string(abstractConnection.getConnectionType()));
        }
    }
}
