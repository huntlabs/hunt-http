module hunt.http.server.HttpServer;

import hunt.http.server.Http1ServerDecoder;
import hunt.http.server.Http2ServerDecoder;
import hunt.http.server.Http2ServerRequestHandler;
import hunt.http.server.HttpServerConnection;
import hunt.http.server.HttpServerContext;
import hunt.http.server.HttpServerHandler;
import hunt.http.server.HttpServerOptions;
import hunt.http.server.ServerHttpHandler;
import hunt.http.server.ServerSessionListener;
import hunt.http.server.WebSocketHandler;

import hunt.http.codec.CommonDecoder;
import hunt.http.codec.CommonEncoder;
import hunt.http.codec.websocket.decode.WebSocketDecoder;

import hunt.http.router;

import hunt.collection.BufferUtils;
import hunt.collection.ByteBuffer;
import hunt.event.EventLoop;
import hunt.util.DateTime;
import hunt.Exceptions;
import hunt.logging;
import hunt.net;
import hunt.util.Lifecycle;

import core.time;
import std.array;


/**
*/
class HttpServer : AbstractLifecycle {

    private NetServer _server;
    private NetServerOptions _serverOptions;
    // private HttpServerHandler httpServerHandler;
    private HttpServerOptions _httpOptions;
    private string host;
    private int port;

    this(HttpServerOptions httpOptions,
            ServerHttpHandler serverHttpHandler, WebSocketHandler webSocketHandler) {
        this(httpOptions, new Http2ServerRequestHandler(serverHttpHandler),
                serverHttpHandler, webSocketHandler);
    }

    this(string host, int port, HttpServerOptions httpOptions,
            ServerHttpHandler serverHttpHandler) {
        httpOptions.setHost(host);
        httpOptions.setPort(port);
        this(httpOptions, new Http2ServerRequestHandler(serverHttpHandler),
                serverHttpHandler, new WebSocketHandler());
    }

    this(string host, int port, HttpServerOptions httpOptions,
            ServerHttpHandler serverHttpHandler, WebSocketHandler webSocketHandler) {
        if (host is null)
            throw new IllegalArgumentException("the http server host is empty");
        httpOptions.setHost(host);
        httpOptions.setPort(port);
        this(httpOptions, new Http2ServerRequestHandler(serverHttpHandler),
                serverHttpHandler, webSocketHandler);
    }

    private this(HttpServerOptions options, ServerSessionListener listener,
            ServerHttpHandler serverHttpHandler, WebSocketHandler webSocketHandler) {
        if (options is null)
            throw new IllegalArgumentException("the http configuration is null");

        this.host = options.getHost();
        this.port = options.getPort();
        _serverOptions = options.getTcpConfiguration();
        if(_serverOptions is null ) {
            _serverOptions = new NetServerOptions();
            options.setTcpConfiguration(_serverOptions);
        }
        this._httpOptions = options;
        
        // httpServerHandler = new HttpServerHandler(options, listener,
        //         serverHttpHandler, webSocketHandler);

        version(WITH_HUNT_SECURITY) {
            import hunt.net.secure.SecureUtils;
            import std.file;
            import std.path;
            
            if (options.isSecureConnectionEnabled()) {
                string sslCertificate = options.sslCertificate();
                string sslPrivateKey = options.sslPrivateKey();
                if(sslCertificate.empty() || sslPrivateKey.empty()) {
                    warningf("No certificate files found. Using the defaults.");
                } else {
	                string currentRootPath = dirName(thisExePath);
                    sslCertificate = buildPath(currentRootPath, sslCertificate);
                    sslPrivateKey = buildPath(currentRootPath, sslPrivateKey);
                    if(!sslCertificate.exists() || !sslPrivateKey.exists()) {
                        warningf("No certificate files found. Using the defaults.");
                    } else {
                        SecureUtils.setServerCertificate(sslCertificate, sslPrivateKey, 
                            options.keystorePassword(), options.keyPassword());
                    }
                }
            }
        }

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

        _server.setHandler(new HttpServerHandler(options, listener, serverHttpHandler, webSocketHandler));

        // For test
        // string responseString = `HTTP/1.1 000 
        // Server: Hunt-HTTP/1.0
        // Date: Tue, 11 Dec 2018 08:17:36 GMT
        // Content-Type: text/plain
        // Content-Length: 13
        // Connection: keep-alive

        // Hello, World!`;


        version (HUNT_DEBUG) {
            if (options.isSecureConnectionEnabled())
                tracef("Listing at: https://%s:%d", host, port);
            else
                tracef("Listing at: http://%s:%d", host, port);
        }
    }

    HttpServerOptions getHttpOptions() {
        return _httpOptions;
    }

    string getHost() {
        return host;
    }

    int getPort() {
        return port;
    }

    bool isTLS() {
        return _httpOptions.isSecureConnectionEnabled();
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

    /**
     * @return A builder that can be used to create an Undertow server instance
     */
    static Builder builder() {
        return new Builder();
    }

    static final class Builder {
        private HttpServerOptions _httpOptions;
        private RouterManager routerManager;
        private Router currentRouter;        

        this() {
            _httpOptions = new HttpServerOptions();
            routerManager = RouterManager.create();
        }

        Builder setListener(int port, string host) {
            _httpOptions.setPort(port);
            _httpOptions.setHost(host);
            return this;
        }

        Builder setTLS(string certificate, string privateKey, string storePassword="", string keyPassword="") {
            _httpOptions.sslCertificate = certificate;
            _httpOptions.sslPrivateKey = privateKey;
            _httpOptions.keystorePassword = storePassword;
            _httpOptions.keyPassword = keyPassword;
            _httpOptions.setSecureConnectionEnabled(true);
            return this;
        }

        /**
         * set default route handler
         */
        Builder setHandler(RoutingHandler handler) {
            addRoute("*", handler);
            return this;
        }
        
        Builder addRoute(string path, RoutingHandler handler) {
            currentRouter = routerManager.register();
            currentRouter.path(path);
            currentRouter.handler( (RoutingContext ctx) { handlerWrap(handler, ctx); });
            return this;
        }

        // Builder addRoute(string path, WebSocketHandler handler) {
        //     return this;
        // }

        protected void handlerWrap(RoutingHandler handler, RoutingContext ctx) {
            try {
                // currentCtx = ctx;
                if(handler !is null) handler(ctx);
            } catch (Exception e) {
                ctx.fail(e);
                errorf("http server handler exception: ", e);
            } finally {
                // currentCtx = null;
            }
        }

        private ServerHttpHandlerAdapter buildHttpHandlerAdapter() {
            ServerHttpHandlerAdapter adapter = new ServerHttpHandlerAdapter();

            adapter.acceptHttpTunnelConnection((request, response, ot, connection) {
                    info("do nothing");
                    // HttpServerContext context = new HttpServerContext(request, response, ot, connection);
                    // request.setAttachment(context);
                    // SimpleRequest r = new SimpleRequest(request, response, ot, cast(HttpConnection)connection);
                    // request.setAttachment(r);
                    // if (tunnel !is null) {
                    //     tunnel(r, connection);
                    // }
                    return true;
                })
                .headerComplete((request, response, ot, connection) {

                    info("headerComplete!!!!!");
                    // SimpleRequest r = new SimpleRequest(request, response, ot, connection);
                    // request.setAttachment(r);
                    // if (_headerComplete != null) {
                    //     _headerComplete(r);
                    // }
                    // requestMeter.mark();
                    return false;
                })
                .content((buffer, request, response, ot, connection) {
                    import hunt.collection.BufferUtils;
                    trace(BufferUtils.toDetailString(buffer));
                    // SimpleRequest r = cast(SimpleRequest) request.getAttachment();
                    // if (r.content !is null) {
                    //     r.content(buffer);
                    // } else {
                    //     r.requestBody.add(buffer);
                    // }
                    request.addBody(buffer);
                    return false;
                })
                .contentComplete((request, response, ot, connection)  {
                    // SimpleRequest r = cast(SimpleRequest) request.getAttachment();
                    // if (r.contentComplete !is null) {
                    //     r.contentComplete(r);
                    // }
                    info("contentComplete!!!!!");
                    HttpServerContext context = new HttpServerContext(request, response, 
                        ot, cast(HttpServerConnection)connection);
                    routerManager.accept(context);
                    return false;
                })
                .messageComplete((request, response, ot, connection)  {
                    // SimpleRequest r = cast(SimpleRequest) request.getAttachment();
                    // if (r.messageComplete != null) {
                    //     r.messageComplete(r);
                    // }
                    // if (!r.getResponse().isAsynchronous()) {
                    //     IOUtils.close(r.getResponse());
                    // }
                    info("messageComplete!!!!!");
                    return true;
                })
                .badMessage((status, reason, request, response, ot, connection)  {
                    // if (_badMessage !is null) {
                    //     if (request.getAttachment() !is null) {
                    //         SimpleRequest r = cast(SimpleRequest) request.getAttachment();
                    //         _badMessage(status, reason, r);
                    //     } else {
                    //         SimpleRequest r = new SimpleRequest(request, response, ot, connection);
                    //         request.setAttachment(r);
                    //         _badMessage(status, reason, r);
                    //     }
                    // }
                })
                .earlyEOF((request, response, ot, connection)  {
                    
                    info("earlyEOF!!!!!");
                    // if (_earlyEof != null) {
                    //     if (request.getAttachment() !is null) {
                    //         SimpleRequest r = cast(SimpleRequest) request.getAttachment();
                    //         _earlyEof(r);
                    //     } else {
                    //         SimpleRequest r = new SimpleRequest(request, response, ot, connection);
                    //         request.setAttachment(r);
                    //         _earlyEof(r);
                    //     }
                    // }
                });

            return adapter;
        }

        HttpServer build() { 
            WebSocketHandler webSocketHandler = new DefaultWebSocketHandler();
            HttpServer server = new HttpServer(_httpOptions, buildHttpHandlerAdapter(), webSocketHandler);

            return server;
        }
    }
}
