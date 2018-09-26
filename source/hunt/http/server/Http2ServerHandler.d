module hunt.http.server.Http2ServerHandler;

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

import hunt.util.exception;
import hunt.string;

import hunt.logging;

import std.range.primitives;


class Http2ServerHandler : AbstractHttpHandler {

    private ServerSessionListener listener;
    private ServerHttpHandler serverHttpHandler;
    private WebSocketHandler webSocketHandler;

    this(Http2Configuration config,
                              ServerSessionListener listener,
                              ServerHttpHandler serverHttpHandler,
                              WebSocketHandler webSocketHandler) {
        super(config);
        this.listener = listener;
        this.serverHttpHandler = serverHttpHandler;
        this.webSocketHandler = webSocketHandler;
    }

    override void sessionOpened(Session session) {
        version(HUNT_DEBUG) trace("New http session...", typeid(session));
        
        if (config.isSecureConnectionEnabled()) {
            SecureSessionFactory factory = config.getSecureSessionFactory();
            SecureSession secureSession = factory.create(session, false, (SecureSession sslSession)  {
                version(HUNT_DEBUG) info("Secure session created...");
                HttpConnection httpConnection;
                string protocol = sslSession.getApplicationProtocol();
                if(protocol.empty)
                    protocol = "http/1.1";

                version(HUNT_DEBUG) {
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
                        throw new IllegalStateException("SSL application protocol negotiates failure. The protocol " ~ 
                            protocol ~ " is not supported");
                }

                //infof("attach http connection: %s", typeid(httpConnection));
                session.attachObject(cast(Object)httpConnection);
                serverHttpHandler.acceptConnection(httpConnection);
            });
            
            //infof("attach secure session: %s", typeid(secureSession));
            session.attachObject(cast(Object)secureSession);
        } else  {
            if (!config.getProtocol().empty) {
                Http1ServerConnection httpConnection = new Http1ServerConnection(config, session, null, 
                    new Http1ServerRequestHandler(serverHttpHandler), listener, webSocketHandler);
                session.attachObject(httpConnection);
                serverHttpHandler.acceptConnection(httpConnection);
            } else {
                HttpVersion httpVersion = HttpVersion.fromString(config.getProtocol());
                if (httpVersion == HttpVersion.Null) {
                    throw new IllegalArgumentException("the protocol " ~ config.getProtocol() ~ " is not support.");
                }

                if(httpVersion == HttpVersion.HTTP_1_1) {
                    Http1ServerConnection httpConnection = new Http1ServerConnection(config, session, null, 
                        new Http1ServerRequestHandler(serverHttpHandler), listener, webSocketHandler);
                    session.attachObject(httpConnection);
                    serverHttpHandler.acceptConnection(httpConnection);
                }
                else if(httpVersion == HttpVersion.HTTP_2) {
                    Http2ServerConnection httpConnection = new Http2ServerConnection(config, session, null, listener);
                    session.attachObject(httpConnection);
                    serverHttpHandler.acceptConnection(httpConnection);
                }
                else
                    throw new IllegalArgumentException("the protocol " ~ config.getProtocol() ~ " is not support.");
            }
        }
    }

}
