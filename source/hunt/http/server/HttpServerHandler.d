module hunt.http.server.HttpServerHandler;

import hunt.http.server.HttpServerOptions;
import hunt.http.server.Http1ServerConnection;
import hunt.http.server.Http1ServerRequestHandler;
import hunt.http.server.Http2ServerConnection;
import hunt.http.server.Http2ServerRequestHandler;
import hunt.http.server.ServerHttpHandler;
import hunt.http.server.ServerSessionListener;
import hunt.http.server.WebSocketHandler;

import hunt.http.HttpConnection;
import hunt.http.HttpOptions;
import hunt.http.HttpVersion;

import hunt.net.secure.SecureSession;
import hunt.net.secure.SecureSessionFactory;
import hunt.net.Connection;

import hunt.Exceptions;
import hunt.logging;
import hunt.text.Common;

import std.range.primitives;
import std.string;

/**
 * 
 */
class HttpServerHandler : HttpConnectionHandler {

    private ServerSessionListener listener;
    private ServerHttpHandler serverHttpHandler;
    private WebSocketHandler webSocketHandler;
    private HttpServerOptions _options;

    this(HttpServerOptions options, ServerSessionListener listener,
            ServerHttpHandler serverHttpHandler, WebSocketHandler webSocketHandler) {
        _options = options;
        this.listener = listener;
        this.serverHttpHandler = serverHttpHandler;
        this.webSocketHandler = webSocketHandler;
    }

    override void connectionOpened(Connection connection) {
        version(HUNT_HTTP_DEBUG_MORE) tracef("New http connection: %s", typeid(cast(Object) connection));

        version(WITH_HUNT_SECURITY) {
            if (_options.isSecureConnectionEnabled()) {
                buildSecureSession(connection);
            } else {
                buildNomalSession(connection);
            }
        } else {
            buildNomalSession(connection);
        }

        super.connectionOpened(connection);
    }

    private void buildNomalSession(Connection connection) {

        connection.setState(ConnectionState.Opening);

        version (HUNT_HTTP_DEBUG)
            infof("Building a new http connection...");
        string protocol = _options.getProtocol();
        
        if (!protocol.empty) {
            Http1ServerConnection httpConnection = new Http1ServerConnection(_options, connection,
                    new Http1ServerRequestHandler(serverHttpHandler, _options), listener, webSocketHandler);
            connection.setAttribute(HttpConnection.NAME, httpConnection);
            serverHttpHandler.acceptConnection(httpConnection);
            connection.setState(ConnectionState.Opened);
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
                Http1ServerConnection httpConnection = new Http1ServerConnection(_options, connection, 
                        new Http1ServerRequestHandler(serverHttpHandler, _options),
                        listener, webSocketHandler);
                connection.setAttribute(HttpConnection.NAME, httpConnection);
                serverHttpHandler.acceptConnection(httpConnection);
                connection.setState(ConnectionState.Opened);
            } else if (icmp(HTTP_2, protocol) == 0) {
                Http2ServerConnection httpConnection = new Http2ServerConnection(_options,
                        connection, listener);
                connection.setAttribute(HttpConnection.NAME, httpConnection);
                serverHttpHandler.acceptConnection(httpConnection);
                connection.setState(ConnectionState.Opened);

            } else {
                string msg = "the protocol " ~ protocol ~ " is not support.";
                version (HUNT_HTTP_DEBUG) {
                    warningf(msg);
                }
                connection.setState(ConnectionState.Error);
                throw new IllegalArgumentException(msg);
            }
        }
    }

version(WITH_HUNT_SECURITY) {
    private void buildSecureSession(Connection connection) {

        import hunt.net.secure.SecureUtils;
        connection.setState(ConnectionState.Securing);
        version(HUNT_HTTP_DEBUG) info("building SecureSession ...");

        SecureSession secureSession = SecureUtils.createServerSession(connection, (SecureSession sslSession) {
            connection.setState(ConnectionState.Secured);
            version (HUNT_DEBUG)
                info("Secure connection created...");

            enum string HTTP_1_1 = HttpVersion.HTTP_1_1.asString();
            enum string HTTP_2 = HttpVersion.HTTP_2.asString();

            HttpConnection httpConnection;
            string protocol = sslSession.getApplicationProtocol();
            if (protocol.empty)
                protocol = _options.getProtocol();
            if (protocol.empty)
                protocol = HTTP_1_1;

            version (HUNT_HTTP_DEBUG) {
                tracef("server connection %s SSL handshake finished. Application protocol: %s",
                    connection.getId(), protocol);
            }

            switch (protocol) {
            case HTTP_1_1:
                httpConnection = new Http1ServerConnection(_options, connection, 
                    new Http1ServerRequestHandler(serverHttpHandler, _options), 
                    listener, webSocketHandler);
                break;

            case HTTP_2:
                httpConnection = new Http2ServerConnection(_options, connection,listener);
                break;

            default:
                throw new IllegalStateException(
                    "SSL application protocol negotiates failure. The protocol "
                    ~ protocol ~ " is not supported");
            }

            connection.setAttribute(HttpConnection.NAME, cast(Object)httpConnection);
            version (HUNT_HTTP_DEBUG_MORE) infof("attach http connection: %s", typeid(httpConnection));

            serverHttpHandler.acceptConnection(httpConnection);
        });

        connection.setAttribute(SecureSession.NAME, cast(Object)secureSession);
    }
}
}
