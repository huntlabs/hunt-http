module hunt.http.codec.http.stream.AbstractHttp2Connection;

import hunt.http.codec.http.decode.Parser;
import hunt.http.codec.http.encode.Http2Generator;
import hunt.http.codec.http.model;


import hunt.http.codec.http.stream.AbstractHttpConnection;
import hunt.http.codec.http.stream.BufferingFlowControlStrategy;
import hunt.http.codec.http.stream.FlowControlStrategy;
import hunt.http.codec.http.stream.Http2Session;
import hunt.http.codec.http.stream.HttpConfiguration;
import hunt.http.codec.http.stream.Session;
import hunt.http.codec.http.stream.SimpleFlowControlStrategy;

import hunt.net.ConnectionType;
import hunt.net.secure.SecureSession;
import hunt.net.Session;

import hunt.Exceptions;

// alias TcpSession = hunt.net.Session.Session;
alias Listener = hunt.http.codec.http.stream.Session.Session.Listener;

abstract class AbstractHttp2Connection :AbstractHttpConnection  {

    protected Http2Session http2Session;
    protected Parser parser;
    protected Http2Generator generator;

    this(HttpConfiguration config,TcpSession tcpSession, 
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
        this.generator = new Http2Generator(config.getMaxDynamicTableSize(), config.getMaxHeaderBlockFragment());
        this.http2Session = initHttp2Session(config, flowControl, listener);
        this.parser = initParser(config);
    }

    // override
    ConnectionType getConnectionType() {
        return ConnectionType.HTTP2;
    }

    abstract protected Http2Session initHttp2Session(HttpConfiguration config, FlowControlStrategy flowControl,
                                                     Listener listener);

    abstract protected Parser initParser(HttpConfiguration config);

    StreamSession getHttp2Session() {
        return http2Session;
    }

}
