module hunt.http.codec.http.stream.AbstractHttp1Connection;

import hunt.http.AbstractHttpConnection;
import hunt.http.HttpOptions;

import hunt.http.codec.http.decode.HttpParser;
import hunt.http.codec.http.encode.Http2Generator;
import hunt.http.HttpVersion;

import hunt.http.HttpConnectionType;
import hunt.net.secure.SecureSession;
import hunt.net.Connection;
import hunt.logging;

alias HttpRequestHandler = HttpParser.RequestHandler;
alias ResponseHandler = HttpParser.ResponseHandler;

/**
*/
abstract class AbstractHttp1Connection : AbstractHttpConnection {

    protected HttpParser parser;
    protected Http2Generator http2Generator;
    protected HttpConfiguration config;

    this(HttpConfiguration config, Connection tcpSession,
                                   HttpRequestHandler requestHandler, ResponseHandler responseHandler) {
        version (HUNT_HTTP_DEBUG) trace("initializing Http1Connection");
        super(tcpSession, HttpVersion.HTTP_1_1);
        this.config = config;
        parser = initHttpParser(config, requestHandler, responseHandler);
        http2Generator = new Http2Generator(config.getMaxDynamicTableSize(), config.getMaxHeaderBlockFragment());
    }

    override HttpConnectionType getConnectionType() {
        return HttpConnectionType.HTTP1;
    }

    protected HttpParser initHttpParser(HttpConfiguration config, HttpRequestHandler requestHandler,
                                                 ResponseHandler responseHandler);

}
