module hunt.http.codec.http.stream.AbstractHttp1Connection;

import hunt.http.codec.http.stream.AbstractHttpConnection;
import hunt.http.codec.http.stream.HttpConfiguration;

import hunt.http.codec.http.decode.HttpParser;
import hunt.http.codec.http.encode.Http2Generator;
import hunt.http.codec.http.model.HttpVersion;

import hunt.net.ConnectionType;
import hunt.net.secure.SecureSession;
import hunt.net.Session;
import hunt.logging;

alias HttpRequestHandler = HttpParser.RequestHandler;
alias ResponseHandler = HttpParser.ResponseHandler;

/**
*/
abstract class AbstractHttp1Connection : AbstractHttpConnection {

    protected HttpParser parser;
    protected Http2Generator http2Generator;
    protected HttpConfiguration config;

    this(HttpConfiguration config, SecureSession secureSession, Session tcpSession,
                                   HttpRequestHandler requestHandler, ResponseHandler responseHandler) {
        version (HUNT_HTTP_DEBUG) trace("initializing Http1Connection");
        super(secureSession, tcpSession, HttpVersion.HTTP_1_1);
        this.config = config;
        parser = initHttpParser(config, requestHandler, responseHandler);
        http2Generator = new Http2Generator(config.getMaxDynamicTableSize(), config.getMaxHeaderBlockFragment());
    }

    ConnectionType getConnectionType() {
        return ConnectionType.HTTP1;
    }

    protected HttpParser initHttpParser(HttpConfiguration config, HttpRequestHandler requestHandler,
                                                 ResponseHandler responseHandler);

}
