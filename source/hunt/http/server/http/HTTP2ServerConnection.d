module hunt.http.server.http.HTTP2ServerConnection;

import hunt.http.server.http.HTTPServerConnection;
import hunt.http.server.http.HTTP2ServerRequestHandler;
import hunt.http.server.http.HTTP2ServerSession;
import hunt.http.server.http.ServerSessionListener;

import hunt.http.codec.http.decode.Parser;
import hunt.http.codec.http.decode.ServerParser;
import hunt.http.codec.http.encode.Generator;

import hunt.http.codec.http.stream;

import hunt.net.ConnectionType;
import hunt.net.secure.SecureSession;
import hunt.net.Session;

import hunt.util.concurrent.CompletableFuture;
import hunt.util.concurrent.Promise;
import hunt.util.exception;

alias Listener = hunt.http.codec.http.stream.Session.Session.Listener;

class HTTP2ServerConnection : AbstractHTTP2Connection , HTTPServerConnection {

    this(HTTP2Configuration config, TcpSession tcpSession, SecureSession secureSession,
                                 ServerSessionListener serverSessionListener) {
        super(config, tcpSession, secureSession, serverSessionListener);
        if (typeid(serverSessionListener) == typeid(HTTP2ServerRequestHandler)) {
            HTTP2ServerRequestHandler handler = cast(HTTP2ServerRequestHandler) serverSessionListener;
            handler.connection = this;
        }
    }

    override
    protected HTTP2Session initHTTP2Session(HTTP2Configuration config, FlowControlStrategy flowControl,
                                            Listener listener) {
        HTTP2ServerSession http2ServerSession = new HTTP2ServerSession(null, this.tcpSession, this.generator,
                cast(ServerSessionListener) listener, flowControl, config.getStreamIdleTimeout());
        http2ServerSession.setMaxLocalStreams(config.getMaxConcurrentStreams());
        http2ServerSession.setMaxRemoteStreams(config.getMaxConcurrentStreams());
        http2ServerSession.setInitialSessionRecvWindow(config.getInitialSessionRecvWindow());
        return http2ServerSession;
    }

    override
    protected Parser initParser(HTTP2Configuration config) {
        return new ServerParser(cast(HTTP2ServerSession) http2Session, config.getMaxDynamicTableSize(), config.getMaxRequestHeadLength());
    }

    override
    ConnectionType getConnectionType() {
        return super.getConnectionType();
    }

    override
    bool isEncrypted() {
        return super.isEncrypted();
    }

    ServerParser getParser() {
        return cast(ServerParser) parser;
    }

    Generator getGenerator() {
        return generator;
    }

    SessionSPI getSessionSPI() {
        return http2Session;
    }

    override
    void upgradeHTTPTunnel(Promise!HTTPTunnelConnection promise) {
        throw new IllegalStateException("the http2 connection can not upgrade to http tunnel");
    }

    override
    CompletableFuture!HTTPTunnelConnection upgradeHTTPTunnel() {
        throw new IllegalStateException("the http2 connection can not upgrade to http tunnel");
    }
}
