module hunt.http.codec.http.stream.AbstractHttp2Connection;

import hunt.http.codec.http.decode.Parser;
import hunt.http.codec.http.encode.Generator;
import hunt.http.codec.http.model;


import hunt.http.codec.http.stream.AbstractHttpConnection;
import hunt.http.codec.http.stream.BufferingFlowControlStrategy;
import hunt.http.codec.http.stream.FlowControlStrategy;
import hunt.http.codec.http.stream.Http2Session;
import hunt.http.codec.http.stream.Http2Configuration;
import hunt.http.codec.http.stream.Session;
import hunt.http.codec.http.stream.SimpleFlowControlStrategy;

import hunt.net.ConnectionType;
import hunt.net.secure.SecureSession;
import hunt.net.Session;

import hunt.lang.exception;

// alias TcpSession = hunt.net.Session.Session;
alias Listener = hunt.http.codec.http.stream.Session.Session.Listener;

abstract class AbstractHttp2Connection :AbstractHttpConnection  {

    protected Http2Session http2Session;
    protected Parser parser;
    protected Generator generator;

    this(Http2Configuration config,TcpSession tcpSession, 
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
        this.http2Session = initHttp2Session(config, flowControl, listener);
        this.parser = initParser(config);
    }

    // override
    ConnectionType getConnectionType() {
        return ConnectionType.HTTP2;
    }

    abstract protected Http2Session initHttp2Session(Http2Configuration config, FlowControlStrategy flowControl,
                                                     Listener listener);

    abstract protected Parser initParser(Http2Configuration config);

    StreamSession getHttp2Session() {
        return http2Session;
    }

}
