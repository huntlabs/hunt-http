module hunt.http.client.Http2ClientHandler;

import hunt.http.client.Http1ClientConnection;
import hunt.http.client.HttpClientContext;
import hunt.http.client.Http2ClientConnection;

import hunt.http.HttpVersion;
import hunt.http.AbstractHttpConnectionHandler;
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

class Http2ClientHandler : AbstractHttpHandler {

    // private Map!(int, HttpClientContext) http2ClientContext;
    HttpClientContext http2ClientContext;

    this(HttpConfiguration config, HttpClientContext http2ClientContext) {
        super(config);
        this.http2ClientContext = http2ClientContext;
    }

    override
    void connectionOpened(Connection connection) {
        HttpClientContext context = http2ClientContext; //.get(connection.getId());

        if (context is null) {
            errorf("http2 client can not get the client context of connection %s", connection.getId());
            connection.close();
            return;
        }

        if (config.isSecureConnectionEnabled()) {
            version(HUNT_DEBUG) {
                info("initilizing a secure connection");
            }

            version(WITH_HUNT_SECURITY) {
                SecureSessionFactory factory = config.getSecureSessionFactory();
                SecureSession secureSession = factory.create(connection, true, (SecureSession sslSession) {

                    string protocol = "http/1.1";
                    string p = sslSession.getApplicationProtocol();
                    if(p.empty)
                        warningf("The selected application protocol is empty. now use default: %s", protocol);
                    else
                        protocol = p;

                    version(HUNT_HTTP_DEBUG) infof("Client connection %s SSL handshake finished. The app protocol is %s", 
                        connection.getId(), protocol);

                    switch (protocol) {
                        case "http/1.1":
                            initializeHttp1ClientConnection(connection, context, sslSession);
                            break;
                        case "h2":
                            initializeHttp2ClientConnection(connection, context, sslSession);
                            break;
                        default:
                            throw new IllegalStateException("SSL application protocol negotiates failure. The protocol " 
                                ~ protocol ~ " is not supported");
                    }
                });

                connection.attachObject(cast(Object)secureSession);
            } else {
                assert(false, "To support SSL, please read Readme.md in project hunt-net .");
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
        try {
            Http1ClientConnection http1ClientConnection = new Http1ClientConnection(config, connection);
            connection.attachObject(http1ClientConnection);
            // context.getPromise().succeeded(http1ClientConnection);
            import hunt.http.client.HttpClientConnection;
            Promise!(HttpClientConnection) promise  = context.getPromise();
            infof("Promise id = %s", promise.id);
            promise.succeeded(http1ClientConnection);

        } catch (Exception t) {
            context.getPromise().failed(t);
        } finally {
            // http2ClientContext.remove(connection.getId());
        }
    }

    private void initializeHttp2ClientConnection(Connection connection, HttpClientContext context) {
        try {
            Http2ClientConnection conn = new Http2ClientConnection(config, connection, context.getListener());
            connection.attachObject(conn);
            context.getListener().setConnection(conn);            
            // connection.initialize(config, cast(Promise!(Http2ClientConnection))context.getPromise(), context.getListener());
            conn.initialize(config, context.getPromise(), context.getListener());
        } finally {
            // http2ClientContext.remove(connection.getId());
        }
    }

    override
    void connectionClosed(Connection connection) {
        try {
            super.connectionClosed(connection);
        } finally {
            // http2ClientContext.remove(connection.getId());
        }
    }

    override
    void failedOpeningConnection(int sessionId, Exception t) {

        auto c = http2ClientContext; //.remove(sessionId);
        if(c !is null)
        {
            auto promise = c.getPromise();
            if(promise !is null)
                promise.failed(t);
        }
        
        // Optional.ofNullable(http2ClientContext.remove(sessionId))
        //         .map(HttpClientContext::getPromise)
        //         .ifPresent(promise => promise.failed(t));
    }

    override
    void exceptionCaught(Connection connection, Exception t) {
        try {
            super.exceptionCaught(connection, t);
        } finally {
            // http2ClientContext; //.remove(connection.getId());
        }
    }

}
