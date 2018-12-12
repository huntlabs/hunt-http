module hunt.http.codec.http.stream.AbstractHttp1Connection;

import hunt.http.codec.http.stream.AbstractHttpConnection;
import hunt.http.codec.http.stream.Http2Configuration;

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
    protected Http2Configuration config;

    this(Http2Configuration config, SecureSession secureSession, Session tcpSession,
                                   HttpRequestHandler requestHandler, ResponseHandler responseHandler) {
        super(secureSession, tcpSession, HttpVersion.HTTP_1_1);
        version (HUNT_DEBUG) trace("initilizing Http1Connection");
        this.config = config;
        parser = initHttpParser(config, requestHandler, responseHandler);
        version(WithHTTP2) {
            http2Generator = new Http2Generator(config.getMaxDynamicTableSize(), config.getMaxHeaderBlockFragment());
        }
    }

    ConnectionType getConnectionType() {
        return ConnectionType.HTTP1;
    }

    protected HttpParser initHttpParser(Http2Configuration config, HttpRequestHandler requestHandler,
                                                 ResponseHandler responseHandler);

}
