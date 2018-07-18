module hunt.http.codec.http.stream.AbstractHTTP2Connection;

import hunt.http.codec.http.decode.Parser;
import hunt.http.codec.http.encode.Generator;
import hunt.http.codec.http.model;

import hunt.http.codec.http.stream.AbstractHTTPConnection;
import hunt.http.codec.http.stream.BufferingFlowControlStrategy;
import hunt.http.codec.http.stream.FlowControlStrategy;
import hunt.http.codec.http.stream.HTTP2Session;
import hunt.http.codec.http.stream.HTTP2Configuration;
import hunt.http.codec.http.stream.Session;
import hunt.http.codec.http.stream.SimpleFlowControlStrategy;

import hunt.net.ConnectionType;
import hunt.net.SecureSession;
import hunt.net.Session;

import hunt.util.exception;

// alias TcpSession = hunt.net.Session.Session;
alias Listener = hunt.http.codec.http.stream.Session.Session.Listener;

abstract class AbstractHTTP2Connection :AbstractHTTPConnection {

    protected HTTP2Session http2Session;
    protected Parser parser;
    protected Generator generator;

    this(HTTP2Configuration config,TcpSession tcpSession, 
    SecureSession secureSession, Listener listener) {
        super(secureSession, tcpSession, HttpVersion.HTTP_2);

        FlowControlStrategy flowControl;
        switch (config.getFlowControlStrategy()) {
            case "buffer":
                flowControl = new BufferingFlowControlStrategy(config.getInitialStreamSendWindow(), 0.5f);
                break;
            case "simple":
                flowControl = new SimpleFlowControlStrategy(config.getInitialStreamSendWindow());
                break;
            default:
                flowControl = new SimpleFlowControlStrategy(config.getInitialStreamSendWindow());
                break;
        }
        this.generator = new Generator(config.getMaxDynamicTableSize(), config.getMaxHeaderBlockFragment());
        this.http2Session = initHTTP2Session(config, flowControl, listener);
        this.parser = initParser(config);
    }

    // override
    ConnectionType getConnectionType() {
        return ConnectionType.HTTP2;
    }

    abstract protected HTTP2Session initHTTP2Session(HTTP2Configuration config, FlowControlStrategy flowControl,
                                                     Listener listener);

    abstract protected Parser initParser(HTTP2Configuration config);

    StreamSession getHttp2Session() {
        return http2Session;
    }

}
