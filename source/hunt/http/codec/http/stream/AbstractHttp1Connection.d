module hunt.http.codec.http.stream.AbstractHttp1Connection;

import hunt.http.codec.http.stream.AbstractHttpConnection;
import hunt.http.codec.http.stream.Http2Configuration;

import hunt.http.codec.http.decode.HttpParser;
import hunt.http.codec.http.encode.Generator;
import hunt.http.codec.http.model.HttpVersion;

import hunt.net.ConnectionType;
import hunt.net.secure.SecureSession;
import hunt.net.Session;

alias RequestHandler = HttpParser.RequestHandler;
alias ResponseHandler = HttpParser.ResponseHandler;

/**
*/
abstract class AbstractHttp1Connection : AbstractHttpConnection {

    protected HttpParser parser;
    protected Generator http2Generator;
    protected Http2Configuration config;

    this(Http2Configuration config, SecureSession secureSession, Session tcpSession,
                                   RequestHandler requestHandler, ResponseHandler responseHandler) {
        super(secureSession, tcpSession, HttpVersion.HTTP_1_1);

        this.config = config;
        parser = initHttpParser(config, requestHandler, responseHandler);
        http2Generator = new Generator(config.getMaxDynamicTableSize(), config.getMaxHeaderBlockFragment());
    }

    ConnectionType getConnectionType() {
        return ConnectionType.HTTP1;
    }

    protected HttpParser initHttpParser(Http2Configuration config, RequestHandler requestHandler,
                                                 ResponseHandler responseHandler);

}
