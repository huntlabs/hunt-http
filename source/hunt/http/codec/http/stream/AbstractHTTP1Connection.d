module hunt.http.codec.http.stream.AbstractHTTP1Connection;

import hunt.http.codec.http.stream.AbstractHTTPConnection;
import hunt.http.codec.http.stream.HTTP2Configuration;

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
abstract class AbstractHTTP1Connection : AbstractHTTPConnection {

    protected HttpParser parser;
    protected Generator http2Generator;
    protected HTTP2Configuration config;

    this(HTTP2Configuration config, SecureSession secureSession, Session tcpSession,
                                   RequestHandler requestHandler, ResponseHandler responseHandler) {
        super(secureSession, tcpSession, HttpVersion.HTTP_1_1);

        this.config = config;
        parser = initHttpParser(config, requestHandler, responseHandler);
        http2Generator = new Generator(config.getMaxDynamicTableSize(), config.getMaxHeaderBlockFragment());
    }

    ConnectionType getConnectionType() {
        return ConnectionType.HTTP1;
    }

    protected HttpParser initHttpParser(HTTP2Configuration config, RequestHandler requestHandler,
                                                 ResponseHandler responseHandler);

}
