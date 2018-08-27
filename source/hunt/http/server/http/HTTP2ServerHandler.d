module hunt.http.server.http.HTTP2ServerHandler;

import hunt.http.server.http.HTTP1ServerConnection;
import hunt.http.server.http.HTTP1ServerRequestHandler;
import hunt.http.server.http.HTTP2ServerConnection;
import hunt.http.server.http.HTTP2ServerRequestHandler;
import hunt.http.server.http.ServerHTTPHandler;
import hunt.http.server.http.ServerSessionListener;
import hunt.http.server.http.WebSocketHandler;

import hunt.http.codec.http.model.HttpVersion;
import hunt.http.codec.http.stream.AbstractHTTPHandler;
import hunt.http.codec.http.stream.HTTP2Configuration;
import hunt.http.codec.http.stream.HTTPConnection;

import hunt.net.secure.SecureSession;
import hunt.net.secure.SecureSessionFactory;
import hunt.net.Session;

import hunt.util.exception;
import hunt.util.string;

import hunt.logging;

import std.range.primitives;


class HTTP2ServerHandler : AbstractHTTPHandler {

    private ServerSessionListener listener;
    private ServerHTTPHandler serverHTTPHandler;
    private WebSocketHandler webSocketHandler;

    this(HTTP2Configuration config,
                              ServerSessionListener listener,
                              ServerHTTPHandler serverHTTPHandler,
                              WebSocketHandler webSocketHandler) {
        super(config);
        this.listener = listener;
        this.serverHTTPHandler = serverHTTPHandler;
        this.webSocketHandler = webSocketHandler;
    }

    override void sessionOpened(Session session) {
        version(HuntDebugMode) trace("New http session...", typeid(session));
        
        if (config.isSecureConnectionEnabled()) {
            SecureSessionFactory factory = config.getSecureSessionFactory();
            SecureSession secureSession = factory.create(session, false, (SecureSession sslSession)  {
                version(HuntDebugMode) info("Secure session created...");
                HTTPConnection httpConnection;
                string protocol = sslSession.getApplicationProtocol();
                if(protocol.empty)
                    protocol = "http/1.1";

                version(HuntDebugMode) {
                    tracef("server session %s SSL handshake finished. Application protocol: %s", 
                        session.getSessionId(), protocol);
                }

                switch (protocol) {
                    case "http/1.1":
                        httpConnection = new HTTP1ServerConnection(config, session, sslSession, 
                            new HTTP1ServerRequestHandler(serverHTTPHandler), listener, webSocketHandler);
                        break;
                    case "h2":
                        httpConnection = new HTTP2ServerConnection(config, session, sslSession, listener);
                        break;
                    default:
                        throw new IllegalStateException("SSL application protocol negotiates failure. The protocol " ~ 
                            protocol ~ " is not supported");
                }

                //infof("attach http connection: %s", typeid(httpConnection));
                session.attachObject(cast(Object)httpConnection);
                serverHTTPHandler.acceptConnection(httpConnection);
            });
            
            //infof("attach secure session: %s", typeid(secureSession));
            session.attachObject(cast(Object)secureSession);
        } else  {
            if (!config.getProtocol().empty) {
                HTTP1ServerConnection httpConnection = new HTTP1ServerConnection(config, session, null, 
                    new HTTP1ServerRequestHandler(serverHTTPHandler), listener, webSocketHandler);
                session.attachObject(httpConnection);
                serverHTTPHandler.acceptConnection(httpConnection);
            } else {
                HttpVersion httpVersion = HttpVersion.fromString(config.getProtocol());
                if (httpVersion == HttpVersion.Null) {
                    throw new IllegalArgumentException("the protocol " ~ config.getProtocol() ~ " is not support.");
                }

                if(httpVersion == HttpVersion.HTTP_1_1) {
                    HTTP1ServerConnection httpConnection = new HTTP1ServerConnection(config, session, null, 
                        new HTTP1ServerRequestHandler(serverHTTPHandler), listener, webSocketHandler);
                    session.attachObject(httpConnection);
                    serverHTTPHandler.acceptConnection(httpConnection);
                }
                else if(httpVersion == HttpVersion.HTTP_2) {
                    HTTP2ServerConnection httpConnection = new HTTP2ServerConnection(config, session, null, listener);
                    session.attachObject(httpConnection);
                    serverHTTPHandler.acceptConnection(httpConnection);
                }
                else
                    throw new IllegalArgumentException("the protocol " ~ config.getProtocol() ~ " is not support.");
            }
        }
    }

}
