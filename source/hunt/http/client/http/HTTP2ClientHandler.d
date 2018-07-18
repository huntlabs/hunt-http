module hunt.http.client.http.HTTP2ClientHandler;

import hunt.http.client.http.HTTP1ClientConnection;
import hunt.http.client.http.HTTP2ClientContext;
import hunt.http.client.http.HTTP2ClientConnection;

import hunt.http.codec.http.model.HttpVersion;
import hunt.http.codec.http.stream.AbstractHTTPHandler;
import hunt.http.codec.http.stream.HTTP2Configuration;
import hunt.net.SecureSession;
import hunt.net.SecureSessionFactory;
import hunt.net.Session;

import hunt.util.concurrent.Promise;
import hunt.util.exception;
import hunt.util.string;

import hunt.container.Map;

import kiss.logger;
import std.array;

class HTTP2ClientHandler : AbstractHTTPHandler {

    private Map!(int, HTTP2ClientContext) http2ClientContext;

    this(HTTP2Configuration config, Map!(int, HTTP2ClientContext) http2ClientContext) {
        super(config);
        this.http2ClientContext = http2ClientContext;
    }

    override
    void sessionOpened(Session session) {
        HTTP2ClientContext context = http2ClientContext.get(session.getSessionId());

        if (context is null) {
            errorf("http2 client can not get the client context of session %s", session.getSessionId());
            session.closeNow();
            return;
        }

        if (config.isSecureConnectionEnabled()) {
            // SecureSessionFactory factory = config.getSecureSessionFactory();
            // session.attachObject(factory.create(session, true, delegate void (SecureSession sslSession) {

            //     string protocol = "http/1.1";
            //     auto p = sslSession.getApplicationProtocol();
            //     if( p.empty)
            //         protocol = p;

            //     // Optional.ofNullable(sslSession.getApplicationProtocol())
            //     //                           .filter(StringUtils::hasText)
            //     //                           .orElse("http/1.1");
            //     info("Client session %s SSL handshake finished. The app protocol is %s", session.getSessionId(), protocol);
            //     switch (protocol) {
            //         case "http/1.1":
            //             initializeHTTP1ClientConnection(session, context, sslSession);
            //             break;
            //         case "h2":
            //             initializeHTTP2ClientConnection(session, context, sslSession);
            //             break;
            //         default:
            //             throw new IllegalStateException("SSL application protocol negotiates failure. The protocol " ~ protocol ~ " is not supported");
            //     }
            // }));
        } else {
            if (config.getProtocol().empty) {
                initializeHTTP1ClientConnection(session, context, null);
            } else {
                HttpVersion httpVersion = HttpVersion.fromString(config.getProtocol());
                if (httpVersion == HttpVersion.Null) {
                    throw new IllegalArgumentException("the protocol " ~ config.getProtocol() ~ " is not support.");
                }
                if(httpVersion == HttpVersion.HTTP_1_1) {
                        initializeHTTP1ClientConnection(session, context, null);
                } else if(httpVersion == HttpVersion.HTTP_2) {
                        initializeHTTP2ClientConnection(session, context, null);
                } else {
                        throw new IllegalArgumentException("the protocol " ~ config.getProtocol() ~ " is not support.");
                }
            }

        }
    }

    private void initializeHTTP1ClientConnection(Session session, HTTP2ClientContext context,
                                                 SecureSession sslSession) {
        try {
            HTTP1ClientConnection http1ClientConnection = new HTTP1ClientConnection(config, session, sslSession);
            session.attachObject(http1ClientConnection);
            context.getPromise().succeeded(http1ClientConnection);
        } catch (Exception t) {
            context.getPromise().failed(t);
        } finally {
            http2ClientContext.remove(session.getSessionId());
        }
    }

    private void initializeHTTP2ClientConnection(Session session, HTTP2ClientContext context,
                                                 SecureSession sslSession) {
        try {
            HTTP2ClientConnection connection = new HTTP2ClientConnection(config, session, sslSession, context.getListener());
            session.attachObject(connection);
            context.getListener().setConnection(connection);
            connection.initialize(config, cast(Promise!(HTTP2ClientConnection))context.getPromise(), context.getListener());
        } finally {
            http2ClientContext.remove(session.getSessionId());
        }
    }

    override
    void sessionClosed(Session session) {
        try {
            super.sessionClosed(session);
        } finally {
            http2ClientContext.remove(session.getSessionId());
        }
    }

    override
    void failedOpeningSession(int sessionId, Exception t) {

        auto c = http2ClientContext.remove(sessionId);
        if(c !is null)
        {
            auto promise = c.getPromise();
            if(promise !is null)
                promise.failed(t);
        }
        
        // Optional.ofNullable(http2ClientContext.remove(sessionId))
        //         .map(HTTP2ClientContext::getPromise)
        //         .ifPresent(promise => promise.failed(t));
    }

    override
    void exceptionCaught(Session session, Exception t) {
        try {
            super.exceptionCaught(session, t);
        } finally {
            http2ClientContext.remove(session.getSessionId());
        }
    }

}
