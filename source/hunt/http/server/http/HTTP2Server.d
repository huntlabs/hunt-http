module hunt.http.server.http.HTTP2Server;

import hunt.http.server.http.HTTP1ServerDecoder;
import hunt.http.server.http.HTTP2ServerDecoder;
import hunt.http.server.http.HTTP2ServerHandler;
import hunt.http.server.http.HTTP2ServerRequestHandler;
import hunt.http.server.http.ServerHTTPHandler;
import hunt.http.server.http.ServerSessionListener;
import hunt.http.server.http.WebSocketHandler;

import hunt.http.codec.common.CommonDecoder;
import hunt.http.codec.common.CommonEncoder;
import hunt.http.codec.http.stream.HTTP2Configuration;
// import hunt.http.codec.websocket.decode.WebSocketDecoder;

import hunt.container.ByteBuffer;
// import hunt.container.BufferUtils;

import hunt.net.AsynchronousTcpSession;
// import hunt.net.Server;
// import hunt.net.Net;
import hunt.net;

import kiss.logger;

import hunt.util.exception;
import hunt.util.LifeCycle;

/**
*/
class HTTP2Server  : AbstractLifeCycle {

    private Server server;
    private HTTP2Configuration http2Configuration;
    private string host;
    private int port;

    this(string host, int port, HTTP2Configuration http2Configuration,
                       ServerHTTPHandler serverHTTPHandler) {
        this(host, port, http2Configuration, new HTTP2ServerRequestHandler(serverHTTPHandler), serverHTTPHandler, new DefaultWebSocketHandler());
    }

    this(string host, int port, HTTP2Configuration http2Configuration,
                       ServerHTTPHandler serverHTTPHandler, WebSocketHandler webSocketHandler) {
        this(host, port, http2Configuration, new HTTP2ServerRequestHandler(serverHTTPHandler), serverHTTPHandler, webSocketHandler);
    }

    this(string host, int port, HTTP2Configuration c,
                       ServerSessionListener listener,
                       ServerHTTPHandler serverHTTPHandler,
                       WebSocketHandler webSocketHandler) {
        if (c is null)
            throw new IllegalArgumentException("the http2 configuration is null");

        if (host is null)
            throw new IllegalArgumentException("the http2 server host is empty");

        this.host = host;
        this.port = port;
        http2ServerHandler = new HTTP2ServerHandler(c, listener, serverHTTPHandler, webSocketHandler);

        HTTP1ServerDecoder http1ServerDecoder = new HTTP1ServerDecoder(null, new HTTP2ServerDecoder());

        // c.getTcpConfiguration().setDecoder(new CommonDecoder(new HTTP1ServerDecoder(null, new HTTP2ServerDecoder())));
        c.getTcpConfiguration().setDecoder(http1ServerDecoder);
        c.getTcpConfiguration().setEncoder(new CommonEncoder());
        c.getTcpConfiguration().setHandler(http2ServerHandler);

        NetServer server = Net.createNetServer();
        this.server = server;
        server.setConfig(c.getTcpConfiguration());

        server.connectHandler((NetSocket sock){
            logInfo("server have accepted a connection...");
            AsynchronousTcpSession session = cast(AsynchronousTcpSession)sock;
            session.handler( ( in ubyte[] data) {      
                    infof("data received (%d bytes): ", data.length); 
                    if(data.length<=64)
                        infof("%(%02X %)", data[0 .. $]);
                    else
                        infof("%(%02X %)", data[0 .. 64]);
                    // infof(cast(string) data); 

                    ByteBuffer buf = ByteBuffer.wrap(cast(byte[])data);
                    http1ServerDecoder.decode(buf, session);
                }
            );
        });

        tracef("Listing at: http://%s:%d", host, port);
        this.http2Configuration = c;
    }

    private HTTP2ServerHandler http2ServerHandler;

    HTTP2Configuration getHttp2Configuration() {
        return http2Configuration;
    }

    string getHost() {
        return host;
    }

    int getPort() {
        return port;
    }

    // ExecutorService getNetExecutorService() {
    //     return server.getNetExecutorService();
    // }

    override
    protected void init() {
        server.listen(host, port);
    }

    override
    protected void destroy() {
        if (server !is null) {
            server.stop();
        }
    }

}
