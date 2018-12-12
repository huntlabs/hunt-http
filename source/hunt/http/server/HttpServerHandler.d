module hunt.http.server.HttpServerHandler;

import hunt.http.server.Http1ServerConnection;
import hunt.http.server.Http1ServerRequestHandler;
import hunt.http.server.Http2ServerConnection;
import hunt.http.server.Http2ServerRequestHandler;
import hunt.http.server.ServerHttpHandler;
import hunt.http.server.ServerSessionListener;
import hunt.http.server.WebSocketHandler;

import hunt.http.codec.http.model.HttpVersion;
import hunt.http.codec.http.stream.AbstractHttpHandler;
import hunt.http.codec.http.stream.Http2Configuration;
import hunt.http.codec.http.stream.HttpConnection;

import hunt.net.secure.SecureSession;
import hunt.net.secure.SecureSessionFactory;
import hunt.net.Session;

import hunt.lang.exception;
import hunt.logging;
import hunt.string;

import std.range.primitives;

class HttpServerHandler : AbstractHttpHandler {

    private ServerSessionListener listener;
    private ServerHttpHandler serverHttpHandler;
    private WebSocketHandler webSocketHandler;

    this(Http2Configuration config, ServerSessionListener listener,
            ServerHttpHandler serverHttpHandler, WebSocketHandler webSocketHandler) {
        super(config);
        this.listener = listener;
        this.serverHttpHandler = serverHttpHandler;
        this.webSocketHandler = webSocketHandler;
    }

    override void sessionOpened(Session session) {
        version (HUNT_DEBUG)
            tracef("New http session");
        // tracef("New http session: %s", typeid(cast(Object) session));
        version(WithTLS) {
            if (config.isSecureConnectionEnabled()) {
                buildSecureSession(session);
            } else {
                buildNomalSession(session);
            }
        } else {
            buildNomalSession(session);
        }
    }

    private void buildNomalSession(Session session) {
        string protocol = config.getProtocol();
        if (!protocol.empty) {
            Http1ServerConnection httpConnection = new Http1ServerConnection(config, session, null,
                    new Http1ServerRequestHandler(serverHttpHandler), listener, webSocketHandler);
            session.attachObject(httpConnection);
            serverHttpHandler.acceptConnection(httpConnection);
        } else {
            enum string HTTP_1_1 = HttpVersion.HTTP_1_1.asString();
            enum string HTTP_2 = HttpVersion.HTTP_2.asString();
            import std.string;
            // HttpVersion httpVersion = HttpVersion.fromString(protocol);
            // if (httpVersion == HttpVersion.Null) {
            //     string msg = "the protocol " ~ protocol ~ " is not support.";
            //     warning(msg);
            //     throw new IllegalArgumentException(msg);
            // }

            if (icmp(HTTP_1_1, protocol) == 0) {
                Http1ServerConnection httpConnection = new Http1ServerConnection(config, session, null,
                        new Http1ServerRequestHandler(serverHttpHandler),
                        listener, webSocketHandler);
                session.attachObject(httpConnection);
                serverHttpHandler.acceptConnection(httpConnection);
            } else if (icmp(HTTP_2, protocol) == 0) {
                Http2ServerConnection httpConnection = new Http2ServerConnection(config,
                        session, null, listener);
                session.attachObject(httpConnection);
                serverHttpHandler.acceptConnection(httpConnection);
            } else {
                string msg = "the protocol " ~ protocol ~ " is not support.";
                version (HUNT_DEBUG) {
                    warningf(msg);
                }
                throw new IllegalArgumentException(msg);
            }
        }
    }

    version(WithTLS)
    private void buildSecureSession(Session session) {
        string protocol = config.getProtocol();
        SecureSessionFactory factory = config.getSecureSessionFactory();
        SecureSession secureSession = factory.create(session, false, (SecureSession sslSession) {
            version (HUNT_DEBUG)
                info("Secure session created...");
            HttpConnection httpConnection;
            string protocol = sslSession.getApplicationProtocol();
            if (protocol.empty)
                protocol = "http/1.1";

            version (HUNT_DEBUG) {
                tracef("server session %s SSL handshake finished. Application protocol: %s",
                    session.getSessionId(), protocol);
            }

            switch (protocol) {
            case "http/1.1":
                httpConnection = new Http1ServerConnection(config, session, sslSession,
                    new Http1ServerRequestHandler(serverHttpHandler), listener, webSocketHandler);
                break;
            case "h2":
                httpConnection = new Http2ServerConnection(config, session, sslSession, listener);
                break;
            default:
                throw new IllegalStateException(
                    "SSL application protocol negotiates failure. The protocol "
                    ~ protocol ~ " is not supported");
            }

            //infof("attach http connection: %s", typeid(httpConnection));
            session.attachObject(cast(Object) httpConnection);
            serverHttpHandler.acceptConnection(httpConnection);
        });

        //infof("attach secure session: %s", typeid(secureSession));
        session.attachObject(cast(Object) secureSession);
    }

}
