module hunt.http.codec.http.stream.AbstractHttp1Connection;

import hunt.http.codec.http.decode.HttpParser;
import hunt.http.codec.http.encode.Http2Generator;

import hunt.http.HttpConnection;
import hunt.http.HttpConnectionType;
import hunt.http.HttpOptions;
import hunt.http.HttpVersion;

import hunt.net.secure.SecureSession;
import hunt.net.Connection;
import hunt.logging;


/**
*/
abstract class AbstractHttp1Connection : AbstractHttpConnection {

    protected HttpParser parser;
    protected Http2Generator http2Generator;
    protected HttpOptions config;

    this(HttpOptions config, Connection tcpSession,
            HttpRequestParsingHandler requestHandler, HttpResponseParsingHandler responseHandler) {
        version (HUNT_HTTP_DEBUG) trace("initializing Http1Connection");
        super(tcpSession, HttpVersion.HTTP_1_1);
        this.config = config;
        parser = initHttpParser(config, requestHandler, responseHandler);
        http2Generator = new Http2Generator(config.getMaxDynamicTableSize(), config.getMaxHeaderBlockFragment());
    }

    override HttpConnectionType getConnectionType() {
        return HttpConnectionType.HTTP1;
    }

    protected HttpParser initHttpParser(HttpOptions config, HttpRequestParsingHandler requestHandler,
                                                 HttpResponseParsingHandler responseHandler);

}
