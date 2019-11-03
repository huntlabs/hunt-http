module hunt.http.server.HttpServer;

import hunt.http.server.GlobalSettings;
import hunt.http.server.Http1ServerDecoder;
import hunt.http.server.Http2ServerDecoder;
import hunt.http.server.Http2ServerRequestHandler;
import hunt.http.server.HttpRequestOptions;
import hunt.http.server.HttpServerConnection;
import hunt.http.server.HttpServerContext;
import hunt.http.server.HttpServerHandler;
import hunt.http.server.HttpServerOptions;
import hunt.http.server.HttpServerRequest;
import hunt.http.server.HttpServerResponse;
import hunt.http.server.ServerHttpHandler;
import hunt.http.server.ServerSessionListener;
import hunt.http.server.WebSocketHandler;

import hunt.http.codec.CommonDecoder;
import hunt.http.codec.CommonEncoder;
import hunt.http.HttpOutputStream;
import hunt.http.codec.websocket.decode.WebSocketDecoder;
import hunt.http.WebSocketConnection;
import hunt.http.codec.websocket.frame;

import hunt.http.routing;
import hunt.http.HttpConnection;
import hunt.http.HttpMethod;
import hunt.http.HttpRequest;
import hunt.http.HttpResponse;
import hunt.http.HttpStatus;
import hunt.http.WebSocketPolicy;

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
import std.file;
import std.path;

import hunt.Functions;

// template Action(T...) {
//     alias Action = void delegate(T);
// }

        
alias BadRequestHandler = ActionN!(HttpServerContext); 

// alias ServerEventHandler = ActionN!(HttpServer, Throwable);
alias ServerErrorHandler = ActionN!(HttpServer, Exception);

/**
*/
class HttpServer : AbstractLifecycle {

    private NetServer _server;
    private NetServerOptions _serverOptions;
    private HttpServerOptions _httpOptions;
    private string host;
    private int port;

    private Action _openSucceededHandler;
    private ActionN!(Throwable) _openFailedHandler;
    private ServerErrorHandler _errorHandler;

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
                serverHttpHandler, new WebSocketHandlerAdapter());
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

        if (options.isSecureConnectionEnabled()) {
            version(WITH_HUNT_SECURITY) {
                import hunt.net.secure.SecureUtils;
                import std.file;
                import std.path;
            
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
            } else {
                assert(false, "Please, add subConfigurations for hunt-http with TLS in dub.json.");
            }
        }

        _server = NetUtil.createNetServer!(ThreadMode.Single)(_serverOptions);

        // set codec
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

        // set handler
        HttpServerHandler serverHandler = new HttpServerHandler(options, listener, serverHttpHandler, webSocketHandler);

        serverHandler.onOpened((Connection conn) {
            version(HUNT_HTTP_DEBUG) {
                infof("Http connection %d opend: %s", conn.getId, typeid(conn));
            }
            version (HUNT_DEBUG) {
                if (options.isSecureConnectionEnabled())
                    tracef("Listing at: https://%s:%d", host, port);
                else
                    tracef("Listing at: http://%s:%d", host, port);
            }

            if(_openSucceededHandler !is null) 
                _openSucceededHandler();
        });

        serverHandler.onOpenFailed((int id, Throwable ex) {
            version(HUNT_HTTP_DEBUG) warning(ex.msg);
            if(_openFailedHandler !is null) 
                _openFailedHandler(ex);
           stop();
        });

        _server.setHandler(serverHandler);
        // _server.setHandler(new HttpServerHandler(options, listener, serverHttpHandler, webSocketHandler));

        // For test
        // string responseString = `HTTP/1.1 000 
        // Server: Hunt-HTTP/1.0
        // Date: Tue, 11 Dec 2018 08:17:36 GMT
        // Content-Type: text/plain
        // Content-Length: 13
        // Connection: keep-alive

        // Hello, World!`;
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

    bool isOpen() {
        return _server.isOpen();
    }

    bool isTLS() {
        return _httpOptions.isSecureConnectionEnabled();
    }

    override protected void initialize() {
        checkWorkingDirectory();
        _server.listen(host, port);
    }

    override protected void destroy() {

        if (_server !is null && _server.isOpen()) {
            version(HUNT_DEBUG) warning("stopping the HttpServer...");
            _server.close();
        }

        version(HUNT_DEBUG) warning("stopping the EventLoop...");
        NetUtil.stopEventLoop();
    }

    private void checkWorkingDirectory() {
        // FIXME: Needing refactor or cleanup -@zhangxueping at 2019-10-18T10:52:02+08:00
        // make sure more directories existed.
        HttpRequestOptions requestOptions = _httpOptions.requestOptions();
        string path = requestOptions.getTempFileAbsolutePath();
        
        if (!path.exists())
            path.mkdirRecurse();
    }

    /* ----------------------------- connect events ----------------------------- */

    HttpServer onOpened(Action handler) {
        _openSucceededHandler = handler;
        return this;
    }

    HttpServer onOpenFailed(ActionN!(Throwable) handler) {
        _openFailedHandler = handler;
        return this;
    }

    HttpServer onError(ServerErrorHandler handler) {
        _errorHandler = handler;
        return this;
    }


    /* -------------------------------------------------------------------------- */
    /*                                   Builder                                  */
    /* -------------------------------------------------------------------------- */

    /**
     * @return A builder that can be used to create an Undertow server instance
     */
    static Builder builder() {
        return new Builder();
    }

    static Builder builder(HttpServerOptions serverOptions) {
        return new Builder(serverOptions);
    }

    /**
     * 
     */
    static final class Builder {
        
        enum PostMethod = HttpMethod.POST.asString();
        enum GetMethod = HttpMethod.GET.asString();

        private HttpServerOptions _httpOptions;
        private RouterManager routerManager;
        private Router currentRouter;
        private WebSocketMessageHandler[string] webSocketHandlers;
        // private bool _canCopyBuffer = false;        

        this() {
            this(new HttpServerOptions());
        }

        this(HttpServerOptions options) {
            _httpOptions = options;
            routerManager = RouterManager.create(_httpOptions.requestOptions());
            
            // set the server options as a global variable
            GlobalSettings.httpServerOptions = _httpOptions;
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
        // Builder enableBufferCopy(bool flag) {
        //     _canCopyBuffer = flag;
        //     return this;
        // }

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

        Builder post(string path, RoutingHandler handler) {
            return addRoute([path], [PostMethod], handler);
        }

        Builder get(string path, RoutingHandler handler) {
            return addRoute([path], [GetMethod], handler);
        }

        Builder addNotFoundRoute(RoutingHandler handler) {
            currentRouter = routerManager.register(DEFAULT_LAST_ROUTER_ID-1);
            currentRouter.path("*").handler( (RoutingContext ctx) { 
                ctx.setStatus(HttpStatus.NOT_FOUND_404);
                handlerWrap(handler, ctx); 
            });
            return this;
        }

        Builder registerWebSocket(string path, WebSocketMessageHandler handler) {
            // auto itemPtr = path in webSocketHandlers;
            // if(itemPtr !is null)
            //     throw new Exception("Handler registered on path: " ~ path);
            
            // WebSocket path should be skipped
            Router webSocketRouter = routerManager.register().path(path);
            webSocketHandlers[path] = handler;
            
            version(HUNT_HTTP_DEBUG) {
                webSocketRouter.handler( (ctx) {  
                    infof("Skip a router path for WebSocket: %s", path);
                });
            }

            return this;
        }

        Builder enableLocalSessionStore() {
            LocalHttpSessionHandler sessionHandler = new LocalHttpSessionHandler(_httpOptions);
            currentRouter = routerManager.register();
            currentRouter.path("*").handler(sessionHandler);
            return this;
        }

        private void handlerWrap(RoutingHandler handler, RoutingContext ctx) {
            try {
                if(handler !is null) handler(ctx);
            } catch (Exception ex) {
                version(HUNT_DEBUG) errorf("route handler exception: %s", ex.msg);
                // version(HUNT_HTTP_DEBUG) error(e);
                if(!ctx.isCommitted()) {
                    HttpServerResponse res = ctx.getResponse();
                    if(res !is null) {
                        res.setStatus(HttpStatus.BAD_REQUEST_400);
                    }
                    ctx.end(ex.msg);
                }
                ctx.fail(ex);
            }
        }

        Builder onError(BadRequestHandler handler) {
            _badRequestHandler = handler;
            return this;
        }

        private void onError(HttpServerContext context) {
            if(_badRequestHandler !is null) {
                _badRequestHandler(context);
            }

            if(!context.isCommitted())
                context.end();
        }

        private BadRequestHandler _badRequestHandler;

        private ServerHttpHandler buildServerHttpHandler() {
            ServerHttpHandlerAdapter adapter = new ServerHttpHandlerAdapter(_httpOptions);

            adapter.acceptHttpTunnelConnection((request, response, ot, connection) {
                    version(HUNT_HTTP_DEBUG) info("acceptHttpTunnelConnection!!!");
                    // if (tunnel !is null) {
                    //     tunnel(r, connection);
                    // }
                    return true;
                })
                .headerComplete((request, response, ot, connection) {
                    version(HUNT_HTTP_DEBUG) info("headerComplete!");
                    
                    HttpServerRequest serverRequest = cast(HttpServerRequest)request;
                    HttpServerContext context = new HttpServerContext(
                        serverRequest, 
                        cast(HttpServerResponse)response, 
                        ot, cast(HttpServerConnection)connection);
                    // request.setAttachment(context);
                    routerManager.accept(context);
                    // serverRequest.onHeaderComplete(_httpOptions.requestOptions());

                    return false;
                })
                .content((buffer, request, response, ot, connection) {
                    version(HUNT_HTTP_DEBUG) tracef("content: %s", BufferUtils.toDetailString(buffer));

                    HttpServerRequest serverRequest = cast(HttpServerRequest)request;
                    serverRequest.onContent(buffer);
                    return false;
                })
                .contentComplete((request, response, ot, connection)  {
                    version(HUNT_HTTP_DEBUG) info("contentComplete!");
                    HttpServerRequest serverRequest = cast(HttpServerRequest)request;
                    serverRequest.onContentComplete();
                    // HttpServerContext context = cast(HttpServerContext) request.getAttachment();
                    // context.onContentComplete();
                    // if (r.contentComplete !is null) {
                    //     r.contentComplete(r);
                    // }
                    return false;
                })
                .messageComplete((request, response, ot, connection)  {
                    version(HUNT_HTTP_DEBUG) info("messageComplete!");
                    HttpServerRequest serverRequest = cast(HttpServerRequest)request;
                    serverRequest.onMessageComplete();
                    // if (!r.getResponse().isAsynchronous()) {
                    //     IOUtils.close(r.getResponse());
                    // }
                    return true;
                })
                .badMessage((status, reason, request, response, ot, connection)  {
                    version(HUNT_DEBUG) warningf("badMessage: status=%d reason=%s", status, reason);

                    version(HUNT_HTTP_DEBUG) tracef("response is null: %s", response is null);
                    if(response is null) {
                        response = new HttpServerResponse(status, reason, null, -1);
                    }
                    
                    HttpServerContext context = new HttpServerContext(
                        cast(HttpServerRequest) request, 
                        cast(HttpServerResponse)response, 
                        ot, cast(HttpServerConnection)connection);

                    onError(context);
                })
                .earlyEOF((request, response, ot, connection)  {
                    version(HUNT_HTTP_DEBUG) info("earlyEOF!");
                });

            return adapter;
        }

        private WebSocketHandler buildWebSocketHandler() {
            WebSocketHandlerAdapter adapter = new WebSocketHandlerAdapter();

            adapter
            .onAcceptUpgrade((HttpRequest request, HttpResponse response, 
                    HttpOutputStream output, HttpConnection connection) {
                string path = request.getURI().getPath();
                WebSocketMessageHandler handler = webSocketHandlers.get(path, null);
                if (handler is null) {
                    response.setStatus(HttpStatus.BAD_REQUEST_400);
                    try {
                        output.write(cast(byte[])("No websocket handler for url: " ~ path));
                    } catch (IOException e) {
                        version(HUNT_DEBUG) errorf("Write http message exception", e.msg);
                    }
                    return false;
                } else {
                    // return handler.acceptUpgrade(request, response, output, connection);
                    return true;
                }
            }) 
            .onOpen((connection) {
                string path = connection.getPath();
                WebSocketMessageHandler handler = webSocketHandlers.get(path, null);
                if(handler !is null)
                    handler.onOpen(connection);
            })
            .onFrame((WebSocketFrame frame, WebSocketConnection connection) {
                string path = connection.getPath();
                WebSocketMessageHandler handler = webSocketHandlers.get(path, null);
                if(handler is null) {
                    return;
                }

                switch (frame.getType()) {
                    case WebSocketFrameType.TEXT:
                        handler.onText((cast(DataFrame) frame).getPayloadAsUTF8(), connection);
                        break;
                        
                    case WebSocketFrameType.BINARY:
                        handler.onBinary(frame.getPayload(), connection);
                        break;
                        
                    case WebSocketFrameType.CLOSE:
                        handler.onClosed(connection);
                        break;

                    case WebSocketFrameType.PING:
                        handler.onPing(connection);
                        break;

                    case WebSocketFrameType.PONG:
                        handler.onPong(connection);
                        break;

                    case WebSocketFrameType.CONTINUATION:
                        handler.onContinuation (frame.getPayload(), connection);
                        break;

                    default: break;
                }
            })
            .onError((Exception ex, WebSocketConnection connection) {
                string path = connection.getPath();
                WebSocketMessageHandler handler = webSocketHandlers.get(path, null);
                if(handler !is null)
                    handler.onError(ex, connection);
            });

            return adapter;
        }

        /* ---------------------------- Options operation --------------------------- */

        Builder maxRequestSize(int size) {
            _httpOptions.requestOptions.setMaxRequestSize(size);
            return this;
        }

        HttpServer build() { 
            return new HttpServer(_httpOptions, buildServerHttpHandler(), buildWebSocketHandler());
        }
    }
}
