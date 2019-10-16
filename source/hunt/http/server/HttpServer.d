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
import hunt.http.codec.http.model.HttpMethod;
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
import std.algorithm;


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
        private bool _canCopyBuffer = false;        

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
        Builder enableBufferCopy(bool flag) {
            _canCopyBuffer = flag;
            return this;
        }

        Builder setHandler(RoutingHandler handler) {
            addRoute("*", handler);
            return this;
        }

        /**
         * register a new router
         */
        Router newRouter() {
            return routerManager.register();
        }

        Builder addRoute(string path, RoutingHandler handler) {
            return addRoute([path], cast(string[])null, handler);
        }

        Builder addRoute(string path, HttpMethod method, RoutingHandler handler) {
            return addRoute([path], [method], handler);
        }
        
        Builder addRoute(string path, HttpMethod[] methods, RoutingHandler handler) {
            string[] ms = map!((m) => m.asString())(methods).array;
            return addRoute([path], ms, handler);
        }

        Builder addRoute(string path, string[] methods, RoutingHandler handler) {
            return addRoute([path], methods, handler);
        }

        Builder addRoute(string[] paths, HttpMethod[] methods, RoutingHandler handler) {
            string[] ms = map!((m) => m.asString())(methods).array;
            return addRoute(paths, ms, handler);
        }

        Builder addRoute(string[] paths, string[] methods, RoutingHandler handler) {
            currentRouter = routerManager.register();
            currentRouter.paths(paths);
            foreach(string m; methods) {
                currentRouter.method(m);
            }
            currentRouter.handler( (RoutingContext ctx) { handlerWrap(handler, ctx); });
            return this;
        }
        
        Builder addRegexRoute(string regex, RoutingHandler handler) {
            return addRegexRoute(regex, cast(string[])null, handler);
        }

        Builder addRegexRoute(string regex, HttpMethod[] methods, RoutingHandler handler) {
            string[] ms = map!((m) => m.asString())(methods).array;
            return addRegexRoute(regex, ms, handler);
        }

        Builder addRegexRoute(string regex, string[] methods, RoutingHandler handler) {
            currentRouter = routerManager.register();
            currentRouter.pathRegex(regex);
            foreach(string m; methods) {
                currentRouter.method(m);
            }
            currentRouter.handler( (RoutingContext ctx) { handlerWrap(handler, ctx); });
            return this;
        }

        // Builder addRoute(string path, WebSocketHandler handler) {
        //     return this;
        // }

        private void handlerWrap(RoutingHandler handler, RoutingContext ctx) {
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
                    version(HUNT_HTTP_DEBUG) info("acceptHttpTunnelConnection!!!");
                    // if (tunnel !is null) {
                    //     tunnel(r, connection);
                    // }
                    return true;
                })
                .headerComplete((request, response, ot, connection) {
                    version(HUNT_HTTP_DEBUG) info("headerComplete!!!!!");
                    
                    HttpServerContext context = new HttpServerContext(request, response, 
                        ot, cast(HttpServerConnection)connection);
                    request.setAttachment(context);
                    routerManager.accept(context);
                    // if (_headerComplete != null) {
                    //     _headerComplete(r);
                    // }
                    // requestMeter.mark();
                    return false;
                })
                .content((buffer, request, response, ot, connection) {
                    version(HUNT_HTTP_DEBUG) {
                        warning(BufferUtils.toDetailString(buffer));
                        string str = cast(string)buffer.getRemaining();
                        info(str);
                    }

                    if(_canCopyBuffer) {
                        ByteBuffer newBuffer = BufferUtils.allocate(buffer.remaining());
                        newBuffer.put(buffer).flip();
                        buffer = newBuffer;
                    }

                    request.onContent(buffer);

                    // request.addBody(buffer);
                    return false;
                })
                .contentComplete((request, response, ot, connection)  {
                    version(HUNT_HTTP_DEBUG) info("contentComplete!!!!!");
                    request.onContentComplete();
                    // HttpServerContext context = cast(HttpServerContext) request.getAttachment();
                    // context.onContentComplete();
                    // if (r.contentComplete !is null) {
                    //     r.contentComplete(r);
                    // }
                    return false;
                })
                .messageComplete((request, response, ot, connection)  {
                    request.onMessageComplete();
                    // if (!r.getResponse().isAsynchronous()) {
                    //     IOUtils.close(r.getResponse());
                    // }
                    version(HUNT_HTTP_DEBUG) info("messageComplete!!!!!");
                    return true;
                })
                .badMessage((status, reason, request, response, ot, connection)  {
                    version(HUNT_HTTP_DEBUG) warning("badMessage: status=%d reason=%s", status, reason);
                })
                .earlyEOF((request, response, ot, connection)  {
                    
                    version(HUNT_HTTP_DEBUG) info("earlyEOF!!!!!");
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
