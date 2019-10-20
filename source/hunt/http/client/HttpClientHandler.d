module hunt.http.client.HttpClientHandler;

import hunt.http.client.HttpClientContext;
import hunt.http.client.HttpClientConnection;
import hunt.http.client.Http1ClientConnection;
import hunt.http.client.Http2ClientConnection;
import hunt.http.HttpVersion;
import hunt.http.HttpConnection;
import hunt.http.HttpOptions;

import hunt.net.Connection;
import hunt.net.secure.SecureSession;


// dfmt off
version(WITH_HUNT_SECURITY) {
    import hunt.net.secure.SecureSessionFactory;
}
// dfmt on

import hunt.concurrency.Promise;
import hunt.Exceptions;
import hunt.text.Common;

import hunt.collection.Map;

import hunt.logging;
import std.array;

/**
*/
class HttpClientHandler : HttpConnectionHandler {

    // private Map!(int, HttpClientContext) _httpClientContext;
    private HttpClientContext _httpClientContext;

    this(HttpOptions config, HttpClientContext httpClientContext) {
        super(config);
        this._httpClientContext = httpClientContext;
    }

    override
    void connectionOpened(Connection connection) {
        HttpClientContext context = _httpClientContext; //.get(connection.getId());

        if (context is null) {
            errorf("http2 client can not get the client context of connection %s", connection.getId());
            connection.close();
            return;
        }

        if (config.isSecureConnectionEnabled()) {
            version(HUNT_DEBUG) {
                infof("initilizing a secure connection: %s", connection.getState());
            }

            version(WITH_HUNT_SECURITY) {
                import hunt.net.secure.SecureUtils;
                connection.setState(ConnectionState.Securing);
                SecureSession secureSession = SecureUtils.createClientSession(connection, (SecureSession sslSession) {

                    // connection.setAttribute(SecureSession.NAME, cast(Object)sslSession);

                    string protocol = "http/1.1";
                    string p = sslSession.getApplicationProtocol();
                    if(p.empty)
                        warningf("The selected application protocol is empty. Now using the default: %s", protocol);
                    else
                        protocol = p;

                    version(HUNT_HTTP_DEBUG) infof("Client connection %s SSL handshake finished. The app protocol is %s", 
                        connection.getId(), protocol);

                    infof("connection state: %s", connection.getState());
                    connection.setState(ConnectionState.Secured);

                    switch (protocol) {
                        case "http/1.1":
                            initializeHttp1ClientConnection(connection, context);
                            break;
                        case "h2":
                            initializeHttp2ClientConnection(connection, context);
                            break;
                        default:
                            throw new IllegalStateException("SSL application protocol negotiates failure. The protocol " 
                                ~ protocol ~ " is not supported");
                    }
                });

                // connection.attachObject(cast(Object)secureSession);

                connection.setAttribute(SecureSession.NAME, cast(Object)secureSession);
            } else {
                assert(false, "To support SSL, please read the Readme.md in project hunt-net.");
            }
        } else {
            version(HUNT_HTTP_DEBUG) {
                info("initilizing a connection");
            }

            if (config.getProtocol().empty) {
                initializeHttp1ClientConnection(connection, context);
            } else {
                HttpVersion httpVersion = HttpVersion.fromString(config.getProtocol());
                if (httpVersion == HttpVersion.Null) {
                    throw new IllegalArgumentException("the protocol " ~ config.getProtocol() ~ " is not support.");
                }
                if(httpVersion == HttpVersion.HTTP_1_1) {
                        initializeHttp1ClientConnection(connection, context);
                } else if(httpVersion == HttpVersion.HTTP_2) {
                        initializeHttp2ClientConnection(connection, context);
                } else {
                        throw new IllegalArgumentException("the protocol " ~ config.getProtocol() ~ " is not support.");
                }
            }

        }
    }

    private void initializeHttp1ClientConnection(Connection connection, HttpClientContext context) {
        Promise!(HttpClientConnection) promise  = context.getPromise();
        assert(promise !is null);
        
        try {
            Http1ClientConnection http1ClientConnection = new Http1ClientConnection(config, connection);
            connection.setAttribute(HttpConnection.NAME, http1ClientConnection);
            promise.succeeded(http1ClientConnection);

        } catch (Exception t) {
            warning(t);
            promise.failed(t);
        } finally {
            // _httpClientContext.remove(connection.getId());
        }
    }

    private void initializeHttp2ClientConnection(Connection connection, HttpClientContext context) {
        try {
            Http2ClientConnection conn = new Http2ClientConnection(config, connection, context.getListener());
            // connection.attachObject(conn);
            connection.setAttribute(HttpConnection.NAME, conn);
            context.getListener().setConnection(conn);            
            // connection.initialize(config, cast(Promise!(Http2ClientConnection))context.getPromise(), context.getListener());
            conn.initialize(config, context.getPromise(), context.getListener());
        } finally {
            // _httpClientContext.remove(connection.getId());
        }
    }

    override
    void connectionClosed(Connection connection) {
        try {
            super.connectionClosed(connection);
        } finally {
            // _httpClientContext.remove(connection.getId());
        }
    }

    override
    void failedOpeningConnection(int sessionId, Throwable t) {

        auto c = _httpClientContext; //.remove(sessionId);
        if(c !is null)
        {
            auto promise = c.getPromise();
            if(promise !is null)
                promise.failed(cast(Exception)t);
        }
        
        // Optional.ofNullable(_httpClientContext.remove(sessionId))
        //         .map(HttpClientContext::getPromise)
        //         .ifPresent(promise => promise.failed(t));
    }

    override
    void exceptionCaught(Connection connection, Throwable t) {
        try {
            super.exceptionCaught(connection, t);
        } finally {
            // _httpClientContext; //.remove(connection.getId());
        }
    }

}
