module hunt.http.server.HttpServer;

import hunt.http.server.Http1ServerDecoder;
import hunt.http.server.Http2ServerDecoder;
import hunt.http.server.HttpServerHandler;
import hunt.http.server.Http2ServerRequestHandler;
import hunt.http.server.ServerHttpHandler;
import hunt.http.server.ServerSessionListener;
import hunt.http.server.WebSocketHandler;

import hunt.http.codec.CommonDecoder;
import hunt.http.codec.CommonEncoder;
import hunt.http.codec.http.stream.Http2Configuration;
import hunt.http.codec.websocket.decode.WebSocketDecoder;

import hunt.collection.ByteBuffer;
import hunt.event.EventLoop;
import hunt.util.DateTime;
import hunt.Exceptions;
import hunt.logging;
import hunt.net;
import hunt.util.Lifecycle;

import core.time;

/**
*/
class HttpServer : AbstractLifecycle {

    private AbstractServer _server;
    private HttpServerHandler httpServerHandler;
    private Http2Configuration http2Configuration;
    private string host;
    private int port;

    this(string host, int port, Http2Configuration http2Configuration,
            ServerHttpHandler serverHttpHandler) {
        this(host, port, http2Configuration, new Http2ServerRequestHandler(serverHttpHandler),
                serverHttpHandler, new WebSocketHandler());
    }

    this(string host, int port, Http2Configuration http2Configuration,
            ServerHttpHandler serverHttpHandler, WebSocketHandler webSocketHandler) {
        this(host, port, http2Configuration, new Http2ServerRequestHandler(serverHttpHandler),
                serverHttpHandler, webSocketHandler);
    }

    this(string host, int port, Http2Configuration c, ServerSessionListener listener,
            ServerHttpHandler serverHttpHandler, WebSocketHandler webSocketHandler) {
        if (c is null)
            throw new IllegalArgumentException("the http2 configuration is null");

        if (host is null)
            throw new IllegalArgumentException("the http2 server host is empty");

        this.host = host;
        this.port = port;
        httpServerHandler = new HttpServerHandler(c, listener,
                serverHttpHandler, webSocketHandler);

        Http1ServerDecoder httpServerDecoder = new Http1ServerDecoder(new WebSocketDecoder(),
                new Http2ServerDecoder());
        CommonDecoder commonDecoder = new CommonDecoder(httpServerDecoder);
        c.getTcpConfiguration().setDecoder(commonDecoder);
        c.getTcpConfiguration().setEncoder(new CommonEncoder());
        c.getTcpConfiguration().setHandler(httpServerHandler);

        _server = NetUtil.createNetServer!(ServerThreadMode.Single)();
        _server.setConfig(c.getTcpConfiguration());

        //         string responseString = `HTTP/1.1 000 
        // Server: Hunt-HTTP/1.0
        // Date: Tue, 11 Dec 2018 08:17:36 GMT
        // Content-Type: text/plain
        // Content-Length: 13
        // Connection: keep-alive

        // Hello, World!`;

        _server.connectionHandler((NetSocket sock) {
            version (HUNT_DEBUG)
                infof("new http session with %s", sock.remoteAddress);
            AsynchronousTcpSession session = cast(AsynchronousTcpSession) sock;
            session.handler((const ubyte[] data) {
                version (HUNT_METRIC) {
                    debug trace("start hadling session data ...");
                    MonoTime startTime = MonoTime.currTime;
                } else version (HUNT_DEBUG) {
                    trace("start hadling session data ...");
                }
                ByteBuffer buf = ByteBuffer.wrap(cast(byte[]) data);
                commonDecoder.decode(buf, session);

                version (HUNT_METRIC) {
                    Duration timeElapsed = MonoTime.currTime - startTime;
                    warningf("handling done for session %d in: %d microseconds",
                    session.getSessionId, timeElapsed.total!(TimeUnit.Microsecond)());
                    tracef("session handling done: %s.", session.toString());
                } else version (HUNT_DEBUG)
                    tracef("session handling done");

                // session.write(responseString, () {
                // version(HUNT_METRIC) {
                //     Duration timeElapsed = MonoTime.currTime - startTime;
                //     warningf("handling done for session %d in: %d microseconds",
                //         session.getSessionId, timeElapsed.total!(TimeUnit.Microsecond)());
                //     debug tracef("session handling done: %s.", session.toString());
                // }                      
                // });
            });
        });
        this.http2Configuration = c;

        version (HUNT_DEBUG) {
            if (c.isSecureConnectionEnabled)
                tracef("Listing at: https://%s:%d", host, port);
            else
                tracef("Listing at: http://%s:%d", host, port);
        }
    }

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
    //     return _server.getNetExecutorService();
    // }

    override protected void initialize() {
        _server.listen(host, port);
    }

    override protected void destroy() {
        if (_server !is null) {
            _server.stop();
        }
    }

}
