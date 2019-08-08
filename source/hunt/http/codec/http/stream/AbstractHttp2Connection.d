module hunt.http.codec.http.stream.AbstractHttp2Connection;

import hunt.http.codec.http.decode.Parser;
import hunt.http.codec.http.encode.Http2Generator;
import hunt.http.codec.http.model;


import hunt.http.AbstractHttpConnection;
import hunt.http.codec.http.stream.BufferingFlowControlStrategy;
import hunt.http.codec.http.stream.FlowControlStrategy;
import hunt.http.codec.http.stream.Http2Session;
import hunt.http.HttpOptions;
import hunt.http.codec.http.stream.Session;
import hunt.http.codec.http.stream.SimpleFlowControlStrategy;

import hunt.http.HttpConnectionType;
import hunt.net.secure.SecureSession;
import hunt.net.Connection;

import hunt.Exceptions;

alias Listener = hunt.http.codec.http.stream.Session.Session.Listener;

abstract class AbstractHttp2Connection : AbstractHttpConnection  {

    protected Http2Session http2Session;
    protected Parser parser;
    protected Http2Generator generator;

    this(HttpOptions config, Connection tcpSession, Listener listener) {
            
        super(tcpSession, HttpVersion.HTTP_2);

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

    override
    HttpConnectionType getConnectionType() {
        return HttpConnectionType.HTTP2;
    }

    abstract protected Http2Session initHttp2Session(HttpOptions config, FlowControlStrategy flowControl,
                                                     Listener listener);

    abstract protected Parser initParser(HttpOptions config);

    StreamSession getHttp2Session() {
        return http2Session;
    }

}
