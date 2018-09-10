module hunt.http.server.http.Http2Server;

import hunt.http.server.http.Http1ServerDecoder;
import hunt.http.server.http.Http2ServerDecoder;
import hunt.http.server.http.Http2ServerHandler;
import hunt.http.server.http.Http2ServerRequestHandler;
import hunt.http.server.http.ServerHttpHandler;
import hunt.http.server.http.ServerSessionListener;
import hunt.http.server.http.WebSocketHandler;

import hunt.http.codec.common.CommonDecoder;
import hunt.http.codec.common.CommonEncoder;
import hunt.http.codec.http.stream.Http2Configuration;
import hunt.http.codec.websocket.decode.WebSocketDecoder;

import hunt.container.ByteBuffer;
// import hunt.container.BufferUtils;

import hunt.net.AsynchronousTcpSession;
import hunt.net;

import hunt.logging;
import hunt.util.exception;
import hunt.util.LifeCycle;

/**
*/
class Http2Server  : AbstractLifeCycle {

    private Server server;
    private Http2Configuration http2Configuration;
    private string host;
    private int port;

    this(string host, int port, Http2Configuration http2Configuration,
                       ServerHttpHandler serverHttpHandler) {
        this(host, port, http2Configuration, 
            new Http2ServerRequestHandler(serverHttpHandler), 
            serverHttpHandler, 
            new WebSocketHandler());
    }

    this(string host, int port, Http2Configuration http2Configuration,
                       ServerHttpHandler serverHttpHandler, WebSocketHandler webSocketHandler) {
        this(host, port, http2Configuration, new Http2ServerRequestHandler(serverHttpHandler), serverHttpHandler, webSocketHandler);
    }

    this(string host, int port, Http2Configuration c,
                       ServerSessionListener listener,
                       ServerHttpHandler serverHttpHandler,
                       WebSocketHandler webSocketHandler) {
        if (c is null)
            throw new IllegalArgumentException("the http2 configuration is null");

        if (host is null)
            throw new IllegalArgumentException("the http2 server host is empty");

        this.host = host;
        this.port = port;
        http2ServerHandler = new Http2ServerHandler(c, listener, serverHttpHandler, webSocketHandler);

        Http1ServerDecoder httpServerDecoder = new Http1ServerDecoder(new WebSocketDecoder(), new Http2ServerDecoder());
        CommonDecoder commonDecoder = new CommonDecoder(httpServerDecoder);
        c.getTcpConfiguration().setDecoder(commonDecoder);
        c.getTcpConfiguration().setEncoder(new CommonEncoder());
        c.getTcpConfiguration().setHandler(http2ServerHandler);

        NetServer server = Net.createNetServer();
        this.server = server;
        server.setConfig(c.getTcpConfiguration());

        server.connectHandler((NetSocket sock){
            info("server have accepted a connection...");
            AsynchronousTcpSession session = cast(AsynchronousTcpSession)sock;
            session.handler( (in ubyte[] data) {     
                    version(HuntDebugMode) { 
                        infof("data received (%d bytes): ", data.length); 
                        if(data.length<=64)
                            infof("%(%02X %)", data[0 .. $]);
                        else
                            infof("%(%02X %) ...", data[0 .. 64]);
                        // infof(cast(string) data); 
                    }
                    ByteBuffer buf = ByteBuffer.wrap(cast(byte[])data);
                    commonDecoder.decode(buf, session);
                }
            );
        });
        this.http2Configuration = c;
        if(c.isSecureConnectionEnabled)
            tracef("Listing at: https://%s:%d", host, port);
        else
            tracef("Listing at: http://%s:%d", host, port);
    }

    private Http2ServerHandler http2ServerHandler;

    Http2Configuration getHttp2Configuration() {
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
    protected void initilize() {
        server.listen(host, port);
    }

    override
    protected void destroy() {
        if (server !is null) {
            server.stop();
        }
    }

}
