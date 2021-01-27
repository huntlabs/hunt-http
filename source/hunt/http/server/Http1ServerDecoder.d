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
import hunt.io.channel;
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

    override DataHandleStatus decode(ByteBuffer buffer, Connection session) {
        DataHandleStatus resultStatus = DataHandleStatus.Done;

        ByteBuffer buf = BufferUtils.toHeapBuffer(buffer);

        scope(exit) {
            BufferUtils.clear(buffer);
        }

        Object attachment = session.getAttribute(HttpConnection.NAME);
        version (HUNT_HTTP_DEBUG) {
            tracef("session type: %s", attachment is null ? "null" : typeid(attachment).name);
        }

        AbstractHttpConnection abstractConnection = cast(AbstractHttpConnection) attachment;
        if (abstractConnection is null) {
            warningf("Bad connection instance: %s", attachment is null ? "null" : typeid(attachment).name);
            return resultStatus;
        }

        switch (abstractConnection.getConnectionType()) {
        case HttpConnectionType.HTTP1: {
                Http1ServerConnection http1Connection = cast(Http1ServerConnection) attachment;
                if (http1Connection.getTunnelConnectionPromise() is null) {
                    HttpParser parser = http1Connection.getParser();
                    version (HUNT_HTTP_DEBUG) trace("Runing http1 parser for a buffer...");
                    while (buf.hasRemaining()) {
                        parser.parseNext(buf);
                        if (http1Connection.getUpgradeHttp2Complete()) {
                            resultStatus = http2ServerDecoder.decode(buf, session);
                            break;
                        } else if (http1Connection.getUpgradeWebSocketComplete()) {
                            resultStatus = webSocketDecoder.decode(buf, session);
                            break;
                        }
                    }

                    HttpParserState parserState = parser.getState();
                    version (HUNT_HTTP_DEBUG) {
                        infof("HTTP1 parsing done with a buffer. Parser state: %s", parserState);
                    }

                    if(parserState == HttpParserState.CONTENT) {
                        resultStatus = DataHandleStatus.Pending;
                    } 
                } else {
                    Http1ServerTunnelConnection tunnelConnection = http1Connection.createHttpTunnel();
                    if (tunnelConnection.content != null) {
                        tunnelConnection.content(buf);
                    }
                }
            }
            break;
        case HttpConnectionType.HTTP2: {
                resultStatus = http2ServerDecoder.decode(buf, session);
            }
            break;
        case HttpConnectionType.WEB_SOCKET: {
                resultStatus = webSocketDecoder.decode(buf, session);
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

        return resultStatus;
    }
}
