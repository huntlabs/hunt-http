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
import hunt.http.HttpOptions;
import hunt.http.codec.websocket.decode.WebSocketDecoder;

import hunt.collection.BufferUtils;
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

    private NetServer _server;
    private NetServerOptions _serverOptions;
    private HttpServerHandler httpServerHandler;
    private HttpConfiguration http2Configuration;
    private string host;
    private int port;

    this(string host, int port, HttpConfiguration http2Configuration,
            ServerHttpHandler serverHttpHandler) {
        this(host, port, http2Configuration, new Http2ServerRequestHandler(serverHttpHandler),
                serverHttpHandler, new WebSocketHandler());
    }

    this(string host, int port, HttpConfiguration http2Configuration,
            ServerHttpHandler serverHttpHandler, WebSocketHandler webSocketHandler) {
        this(host, port, http2Configuration, new Http2ServerRequestHandler(serverHttpHandler),
                serverHttpHandler, webSocketHandler);
    }

    this(string host, int port, HttpConfiguration c, ServerSessionListener listener,
            ServerHttpHandler serverHttpHandler, WebSocketHandler webSocketHandler) {
        if (c is null)
            throw new IllegalArgumentException("the http2 configuration is null");

        if (host is null)
            throw new IllegalArgumentException("the http2 server host is empty");

        this.host = host;
        this.port = port;
        _serverOptions = cast(NetServerOptions)c.getTcpConfiguration();
        if(_serverOptions is null ) {
            _serverOptions = new NetServerOptions();
        }
        httpServerHandler = new HttpServerHandler(c, listener,
                serverHttpHandler, webSocketHandler);

        // Http1ServerDecoder httpServerDecoder = new Http1ServerDecoder(new WebSocketDecoder(),
        //         new Http2ServerDecoder());
        // CommonDecoder commonDecoder = new CommonDecoder(httpServerDecoder);
        // c.getTcpConfiguration().setDecoder(commonDecoder);
        // c.getTcpConfiguration().setEncoder(new CommonEncoder());
        // c.getTcpConfiguration().setHandler(httpServerHandler);

        _server = NetUtil.createNetServer!(ThreadMode.Single)(_serverOptions);

        _server.setCodec(new class Codec {
            private CommonEncoder encoder;
            private CommonDecoder decoder;

            this() {
                encoder = new CommonEncoder();

                Http1ServerDecoder httpServerDecoder = new Http1ServerDecoder(
                            new WebSocketDecoder(),
                            new Http2ServerDecoder());
                decoder = new CommonDecoder(httpServerDecoder);
            }

            Encoder getEncoder() {
                return encoder;
            }

            Decoder getDecoder() {
                return decoder;
            }
        });

        _server.setHandler(new HttpServerHandler(c, listener,
                serverHttpHandler, webSocketHandler));

        // _server.setConfig(c.getTcpConfiguration());

        //         string responseString = `HTTP/1.1 000 
        // Server: Hunt-HTTP/1.0
        // Date: Tue, 11 Dec 2018 08:17:36 GMT
        // Content-Type: text/plain
        // Content-Length: 13
        // Connection: keep-alive

        // Hello, World!`;

        // _server.connectionHandler((NetSocket sock) {
        //     version (HUNT_DEBUG)
        //         infof("new http session with %s", sock.remoteAddress);
        //     AsynchronousTcpSession session = cast(AsynchronousTcpSession) sock;
        //     session.handler((ByteBuffer buffer) {
        //         version (HUNT_METRIC) {
        //             debug trace("start hadling session data ...");
        //             MonoTime startTime = MonoTime.currTime;
        //         } else version (HUNT_DEBUG_MORE) {
        //             trace("start hadling session data ...");
        //         }
        //         commonDecoder.decode(buffer, session);

        //         version (HUNT_METRIC) {
        //             Duration timeElapsed = MonoTime.currTime - startTime;
        //             warningf("handling done for session %d in: %d microseconds",
        //             session.getId, timeElapsed.total!(TimeUnit.Microsecond)());
        //             tracef("session handling done: %s.", session.toString());
        //         } else version (HUNT_HTTP_DEBUG)
        //             tracef("session handling done");

        //         // session.write(responseString, () {
        //         // version(HUNT_METRIC) {
        //         //     Duration timeElapsed = MonoTime.currTime - startTime;
        //         //     warningf("handling done for session %d in: %d microseconds",
        //         //         session.getId, timeElapsed.total!(TimeUnit.Microsecond)());
        //         //     debug tracef("session handling done: %s.", session.toString());
        //         // }                      
        //         // });
        //     });
        // });
        this.http2Configuration = c;

        version (HUNT_DEBUG) {
            if (c.isSecureConnectionEnabled)
                tracef("Listing at: https://%s:%d", host, port);
            else
                tracef("Listing at: http://%s:%d", host, port);
        }
    }

    HttpConfiguration getHttp2Configuration() {
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
        // if (_server !is null) {
        //     _server.stop();
        // }
    }

}
