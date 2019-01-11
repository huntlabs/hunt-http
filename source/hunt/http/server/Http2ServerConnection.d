module hunt.http.server.Http2ServerConnection;

import hunt.http.server.HttpServerConnection;
import hunt.http.server.Http2ServerRequestHandler;
import hunt.http.server.Http2ServerSession;
import hunt.http.server.ServerSessionListener;

import hunt.http.codec.http.decode.Parser;
import hunt.http.codec.http.decode.ServerParser;
import hunt.http.codec.http.encode.Http2Generator;

import hunt.http.codec.http.stream;

import hunt.net.ConnectionType;
import hunt.net.secure.SecureSession;
import hunt.net.Session;

import hunt.concurrency.CompletableFuture;
import hunt.concurrency.Promise;
import hunt.Exceptions;

alias Listener = hunt.http.codec.http.stream.Session.Session.Listener;

class Http2ServerConnection : AbstractHttp2Connection , HttpServerConnection {

    this(Http2Configuration config, TcpSession tcpSession, SecureSession secureSession,
                                 ServerSessionListener serverSessionListener) {
        super(config, tcpSession, secureSession, serverSessionListener);
        if (typeid(serverSessionListener) == typeid(Http2ServerRequestHandler)) {
            Http2ServerRequestHandler handler = cast(Http2ServerRequestHandler) serverSessionListener;
            handler.connection = this;
        }
    }

    override
    protected Http2Session initHttp2Session(Http2Configuration config, FlowControlStrategy flowControl,
                                            Listener listener) {
        Http2ServerSession http2ServerSession = new Http2ServerSession(null, this.tcpSession, this.generator,
                cast(ServerSessionListener) listener, flowControl, config.getStreamIdleTimeout());
        http2ServerSession.setMaxLocalStreams(config.getMaxConcurrentStreams());
        http2ServerSession.setMaxRemoteStreams(config.getMaxConcurrentStreams());
        http2ServerSession.setInitialSessionRecvWindow(config.getInitialSessionRecvWindow());
        return http2ServerSession;
    }

    override
    protected Parser initParser(Http2Configuration config) {
        return new ServerParser(cast(Http2ServerSession) http2Session, config.getMaxDynamicTableSize(), config.getMaxRequestHeadLength());
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

    Http2Generator getGenerator() {
        return generator;
    }

    SessionSPI getSessionSPI() {
        return http2Session;
    }

    override
    void upgradeHttpTunnel(Promise!HttpTunnelConnection promise) {
        throw new IllegalStateException("the http2 connection can not upgrade to http tunnel");
    }

    override
    CompletableFuture!HttpTunnelConnection upgradeHttpTunnel() {
        throw new IllegalStateException("the http2 connection can not upgrade to http tunnel");
    }
}
