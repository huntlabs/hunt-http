module hunt.http.server.HttpServerHandler;

import hunt.http.server.Http1ServerConnection;
import hunt.http.server.Http1ServerRequestHandler;
import hunt.http.server.Http2ServerConnection;
import hunt.http.server.Http2ServerRequestHandler;
import hunt.http.server.ServerHttpHandler;
import hunt.http.server.ServerSessionListener;
import hunt.http.server.WebSocketHandler;

import hunt.http.HttpVersion;
import hunt.http.AbstractHttpConnectionHandler;
import hunt.http.HttpOptions;
import hunt.http.HttpConnection;

import hunt.net.secure.SecureSession;
import hunt.net.secure.SecureSessionFactory;
import hunt.net.Connection;

import hunt.Exceptions;
import hunt.logging;
import hunt.text.Common;

import std.range.primitives;
import std.string;

/**
*/
class HttpServerHandler : AbstractHttpHandler {

    private ServerSessionListener listener;
    private ServerHttpHandler serverHttpHandler;
    private WebSocketHandler webSocketHandler;

    this(HttpConfiguration config, ServerSessionListener listener,
            ServerHttpHandler serverHttpHandler, WebSocketHandler webSocketHandler) {
        super(config);
        this.listener = listener;
        this.serverHttpHandler = serverHttpHandler;
        this.webSocketHandler = webSocketHandler;
    }

    override void connectionOpened(Connection connection) {
        version (HUNT_DEBUG)
            tracef("New http connection");
        // tracef("New http connection: %s", typeid(cast(Object) connection));
        version(WITH_HUNT_SECURITY) {
            if (config.isSecureConnectionEnabled()) {
                buildSecureSession(connection);
            } else {
                buildNomalSession(connection);
            }
        } else {
            buildNomalSession(connection);
        }
    }

    private void buildNomalSession(Connection connection) {
        string protocol = config.getProtocol();
        if (!protocol.empty) {
            Http1ServerConnection httpConnection = new Http1ServerConnection(config, connection,
                    new Http1ServerRequestHandler(serverHttpHandler), listener, webSocketHandler);
            connection.attachObject(httpConnection);
            serverHttpHandler.acceptConnection(httpConnection);
        } else {
            enum string HTTP_1_1 = HttpVersion.HTTP_1_1.asString();
            enum string HTTP_2 = HttpVersion.HTTP_2.asString();
            // HttpVersion httpVersion = HttpVersion.fromString(protocol);
            // if (httpVersion == HttpVersion.Null) {
            //     string msg = "the protocol " ~ protocol ~ " is not support.";
            //     warning(msg);
            //     throw new IllegalArgumentException(msg);
            // }

            if (icmp(HTTP_1_1, protocol) == 0) {
                Http1ServerConnection httpConnection = new Http1ServerConnection(config, connection, 
                        new Http1ServerRequestHandler(serverHttpHandler),
                        listener, webSocketHandler);
                connection.attachObject(httpConnection);
                serverHttpHandler.acceptConnection(httpConnection);
            } else if (icmp(HTTP_2, protocol) == 0) {
                Http2ServerConnection httpConnection = new Http2ServerConnection(config,
                        connection, listener);
                connection.attachObject(httpConnection);
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

    version(WITH_HUNT_SECURITY)
    private void buildSecureSession(Connection connection) {

        import hunt.net.secure.SecureUtils;
        connection.setState(ConnectionState.Securing);
        SecureSession secureSession = SecureUtils.createServerSession(connection, (SecureSession sslSession) {
            version (HUNT_DEBUG)
                info("Secure connection created...");

            connection.setAttribute(SecureSession.NAME, cast(Object)sslSession);

            HttpConnection httpConnection;
            string protocol = sslSession.getApplicationProtocol();
            if (protocol.empty)
                protocol = config.getProtocol();
            if (protocol.empty)
                protocol = "http/1.1";

            version (HUNT_DEBUG) {
                tracef("server connection %s SSL handshake finished. Application protocol: %s",
                    connection.getId(), protocol);
            }

            switch (protocol) {
            case "http/1.1":
                httpConnection = new Http1ServerConnection(config, connection, 
                    new Http1ServerRequestHandler(serverHttpHandler), listener, webSocketHandler);
                break;
            case "h2":
                httpConnection = new Http2ServerConnection(config, connection,listener);
                break;
            default:
                throw new IllegalStateException(
                    "SSL application protocol negotiates failure. The protocol "
                    ~ protocol ~ " is not supported");
            }

            //infof("attach http connection: %s", typeid(httpConnection));
            connection.attachObject(cast(Object) httpConnection);
            connection.setAttribute(HttpConnection.NAME, cast(Object)httpConnection);

            serverHttpHandler.acceptConnection(httpConnection);
        });

        //infof("attach secure connection: %s", typeid(secureSession));
        connection.attachObject(cast(Object) secureSession);
    }

}
