module hunt.http.server.HttpServer;

import hunt.http.server.ClientAuth;
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
import hunt.http.codec.websocket.decode.WebSocketDecoder;
import hunt.http.codec.websocket.frame;

import hunt.http.routing;
import hunt.http.HttpConnection;
import hunt.http.HttpHeader;
import hunt.http.HttpMethod;
import hunt.http.HttpOutputStream;
import hunt.http.HttpRequest;
import hunt.http.HttpResponse;
import hunt.http.HttpStatus;
import hunt.http.WebSocketConnection;
import hunt.http.WebSocketPolicy;

import hunt.io.BufferUtils;
import hunt.io.ByteBuffer;
import hunt.event.EventLoop;
import hunt.Exceptions;
import hunt.Functions;
import hunt.logging;
import hunt.net;
import hunt.util.DateTime;
import hunt.util.AbstractLifecycle;

import core.time;

import std.array;
import std.algorithm;
import std.file;
import std.path;
import std.string;


version(WITH_HUNT_TRACE) {
    import hunt.net.util.HttpURI;
    import hunt.trace.Constrants;
    import hunt.trace.Endpoint;
    import hunt.trace.HttpSender;
    import hunt.trace.Span;
    import hunt.trace.Tracer;
    import hunt.trace.TracingOptions;

    import std.conv;
    import std.format;
}
        
alias BadRequestHandler = ActionN!(HttpServerContext); 
alias ServerErrorHandler = ActionN!(HttpServer, Exception);

/**
 * 
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

    this(string host, ushort port, HttpServerOptions httpOptions,
            ServerHttpHandler serverHttpHandler) {
        httpOptions.setHost(host);
        httpOptions.setPort(port);
        this(httpOptions, new Http2ServerRequestHandler(serverHttpHandler),
                serverHttpHandler, new WebSocketHandlerAdapter());
    }

    this(string host, ushort port, HttpServerOptions httpOptions,
            ServerHttpHandler serverHttpHandler, WebSocketHandler webSocketHandler) {
        if (host is null)
            throw new IllegalArgumentException("the http server host is empty");
        httpOptions.setHost(host);
        httpOptions.setPort(port);
        this(httpOptions, new Http2ServerRequestHandler(serverHttpHandler),
                serverHttpHandler, webSocketHandler);
    }

    this(HttpServerOptions options, ServerSessionListener listener,
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
                KeyCertOptions certOptions = options.getKeyCertOptions();
                if(certOptions is null) {
                    warningf("No certificate files found. Using the defaults.");
                } else {
                    SecureUtils.setServerCertificate(certOptions);
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
                infof("A new http connection %d opend: %s", conn.getId, typeid(conn));
            }
            version (HUNT_DEBUG) {
                if (options.isSecureConnectionEnabled())
                    infof("Opend a secured http connection: %s", conn.getRemoteAddress());
                else
                    infof("Opend a http connection: %s", conn.getRemoteAddress());
            }

            // TODO: Tasks pending completion -@zhangxueping at 2020-05-18T16:27:44+08:00
            // Pass the connection to _openSucceededHandler();
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

        // version(HUNT_DEBUG) warning("stopping the EventLoop...");
        // NetUtil.stopEventLoop();
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
        enum PutMethod = HttpMethod.PUT.asString();
        enum DeleteMethod = HttpMethod.DELETE.asString();

        private HttpServerOptions _httpOptions;
        private RouterManager _routerManager;               // default route manager
        private RouterManager[string] _hostManagerGroup; // route manager group for host
        private RouterManager[string] _pathManagerGroup; // route manager group for path
        private Router _currentRouter;
        private WebSocketMessageHandler[string] _webSocketHandlers;
        // private bool _canCopyBuffer = false;       
        
        // SSL/TLS settings
        private bool _isCertificateAuth = false;
        private string _tlsCaFile;
        private string _tlsCaPassworld;
        private string _tlsCertificate;
        private string _tlsPrivateKey;
        private string _tlsCertPassword;
        private string _tlsKeyPassword;


        this() {
            this(new HttpServerOptions());
        }

        this(HttpServerOptions options) {
            _httpOptions = options;
            _routerManager = RouterManager.create();
            
            // set the server options as a global variable
            GlobalSettings.httpServerOptions = _httpOptions;
        }

        Builder setListener(ushort port) {
            _httpOptions.setPort(port);
            return this;
        }

        Builder setListener(ushort port, string host) {
            _httpOptions.setPort(port);
            _httpOptions.setHost(host);
            return this;
        }

        Builder ioThreadSize(uint value) {
            _httpOptions.getTcpConfiguration().ioThreadSize = value;
            return this;
        }

        Builder workerThreadSize(uint value) {
            _httpOptions.getTcpConfiguration().workerThreadSize = value;
            return this;
        }

        // Certificate Authority (CA) certificate
        Builder setCaCert(string caFile, string caPassword) {
            _tlsCaFile = caFile;
            _tlsCaPassworld = caPassword;
            return this;
        }

        Builder setTLS(string certificate, string privateKey, string certPassword="", string keyPassword="") {
            _isCertificateAuth = true;
            _tlsCertificate = certificate;
            _tlsPrivateKey = privateKey;
            _tlsCertPassword = certPassword;
            _tlsKeyPassword = keyPassword;
            return this;
        }

        Builder requiresClientAuth() {
            _httpOptions.setClientAuth(ClientAuth.REQUIRED);
            return this;
        }

        Builder setHandler(RoutingHandler handler) {
            addRoute(["*"], null, handler);
            return this;
        }

        /**
         * register a new router
         */
        // Router newRouter() {
        //     return _routerManager.register();
        // }

        Builder addRoute(string path, RoutingHandler handler) {
            return addRoute([path], cast(string[])null, handler);
        }

        Builder addRoute(string path, HttpMethod method, RoutingHandler handler) {
            return addRoute([path], [method.toString()], handler);
        }
        
        Builder addRoute(string path, HttpMethod[] methods, RoutingHandler handler) {
            string[] ms = map!((m) => m.asString())(methods).array;
            return addRoute([path], ms, handler);
        }

        // Builder addRoute(string path, string[] methods, RoutingHandler handler) {
        //     return addRoute([path], methods, handler);
        // }

        // Builder addRoute(string[] paths, HttpMethod[] methods, RoutingHandler handler) {
        //     string[] ms = map!((m) => m.asString())(methods).array;
        //     return addRoute(paths, ms, handler);
        // }

        Builder addRoute(string[] paths, string[] methods, RoutingHandler handler, 
                string groupName=null, RouteGroupType groupType = RouteGroupType.Host) {
            if(groupName.empty) {
                _currentRouter = _routerManager.register();
            } else {
                _currentRouter = getGroupRouterManager(groupName, groupType).register();
            }

            version(HUNT_HTTP_DEBUG) { 
                tracef("routeid: %d, paths: %s, group: %s", _currentRouter.getId(), paths, groupName);
            }

            _currentRouter.paths(paths);
            foreach(string m; methods) {
                _currentRouter.method(m);
            }
            _currentRouter.handler( (RoutingContext ctx) { handlerWrap(handler, ctx); });
            return this;
        }

        Builder addRoute(string[] paths, string[] methods, RouteHandler handler, 
                string groupName=null, RouteGroupType groupType = RouteGroupType.Host) {
            if(groupName.empty) {
                _currentRouter = _routerManager.register();
            } else {
                _currentRouter = getGroupRouterManager(groupName, groupType).register();
            }
            version(HUNT_HTTP_DEBUG) tracef("routeid: %d, paths: %s", _currentRouter.getId(), paths);
            _currentRouter.paths(paths);
            foreach(string m; methods) {
                _currentRouter.method(m);
            }
            _currentRouter.handler( (RoutingContext ctx) { handlerWrap(handler, ctx); });
            return this;
        }
        
        // Builder addRegexRoute(string regex, RoutingHandler handler) {
        //     return addRegexRoute(regex, cast(string[])null, handler);
        // }

        // Builder addRegexRoute(string regex, HttpMethod[] methods, RoutingHandler handler) {
        //     string[] ms = map!((m) => m.asString())(methods).array;
        //     return addRegexRoute(regex, ms, handler);
        // }

        Builder addRegexRoute(string regex, string[] methods, RoutingHandler handler, 
                string groupName=null, RouteGroupType groupType = RouteGroupType.Host) {
            if(groupName.empty) {
                _currentRouter = _routerManager.register();
            } else {
                _currentRouter = getGroupRouterManager(groupName, groupType).register();
            }
            version(HUNT_HTTP_DEBUG) tracef("routeid: %d, paths: %s", _currentRouter.getId(), regex);
            _currentRouter.pathRegex(regex);
            foreach(string m; methods) {
                _currentRouter.method(m);
            }
            _currentRouter.handler( (RoutingContext ctx) { handlerWrap(handler, ctx); });
            return this;
        }

        private RouterManager getGroupRouterManager(string groupName, RouteGroupType groupType) {
            RouterManager manager;
            if(groupType == RouteGroupType.Host) {
                auto itemPtr = groupName in _hostManagerGroup;
                if(itemPtr is null) {
                    manager = RouterManager.create();
                    _hostManagerGroup[groupName] = manager;
                } else {
                    manager = *itemPtr;
                }
            } else {
                auto itemPtr = groupName in _pathManagerGroup;
                if(itemPtr is null) {
                    manager = RouterManager.create();
                    _pathManagerGroup[groupName] = manager;
                } else {
                    manager = *itemPtr;
                }
            }
            
            return manager;
        }

        Builder onGet(string path, RoutingHandler handler, 
                string groupName=null, RouteGroupType groupType = RouteGroupType.Host) {
            return addRoute([path], [GetMethod], handler, groupName, groupType);
        }

        Builder onPost(string path, RoutingHandler handler, 
                string groupName=null, RouteGroupType groupType = RouteGroupType.Host) {
            return addRoute([path], [PostMethod], handler, groupName, groupType);
        }

        Builder onPut(string path, RoutingHandler handler, 
                string groupName=null, RouteGroupType groupType = RouteGroupType.Host) {
            return addRoute([path], [PutMethod], handler, groupName, groupType);
        }

        Builder onDelete(string path, RoutingHandler handler, 
                string groupName=null, RouteGroupType groupType = RouteGroupType.Host) {
            return addRoute([path], [DeleteMethod], handler, groupName, groupType);
        }

        Builder onRequest(string method, string path, RoutingHandler handler, 
                string groupName=null, RouteGroupType groupType = RouteGroupType.Host) {
            return addRoute([path], [method], handler, groupName, groupType);
        }

        Builder setDefaultRequest(RoutingHandler handler) {
            _currentRouter = _routerManager.register(DEFAULT_LAST_ROUTER_ID-1);
            version(HUNT_HTTP_DEBUG) tracef("routeid: %d, paths: %s", _currentRouter.getId(), "*");
            _currentRouter.path("*").handler( (RoutingContext ctx) { 
                ctx.setStatus(HttpStatus.NOT_FOUND_404);
                handlerWrap(handler, ctx); 
            });
            return this;
        }

        alias addNotFoundRoute = setDefaultRequest;

        Builder resource(string path, string localPath, bool canList = true, 
                string groupName=null, RouteGroupType groupType = RouteGroupType.Host) {
            return resource(path, new DefaultResourceHandler(localPath).isListingEnabled(canList), 
                groupName, groupType);
        }

        Builder resource(string path, AbstractResourceHandler handler, 
                string groupName=null, RouteGroupType groupType = RouteGroupType.Host) {
            path = path.strip();
            assert(path.length > 0, "The path can't be empty");

            if(path[0] != '/')
                path = "/" ~ path;
            
            string staticPath;
            if(path[$-1] != '/') {
                staticPath = path;
                path ~= "/";
            } else {
                staticPath = path[0..$-1];
            }

            path ~= "*";
            version(HUNT_HTTP_DEBUG) warningf("path: %s, staticPath: %s", path, staticPath);

            if(path == staticPath || staticPath.empty()) {
                return addRoute([path], cast(string[])null, handler, groupName, groupType);
            } else {
                return addRoute([path, staticPath], cast(string[])null, handler, groupName, groupType);
            }
        }

        Builder websocket(string path, WebSocketMessageHandler handler) {
            auto itemPtr = path in _webSocketHandlers;
            if(itemPtr !is null)
                throw new Exception("Handler registered on path: " ~ path);
            
            // WebSocket path should be skipped
            Router webSocketRouter = _routerManager.register().path(path);
            version(HUNT_HTTP_DEBUG) tracef("routeid: %d, paths: %s", webSocketRouter.getId(), path);
            _webSocketHandlers[path] = handler;
            
            version(HUNT_HTTP_DEBUG) {
                webSocketRouter.handler( (ctx) {  
                    infof("Skip a router path for WebSocket: %s", path);
                });
            }

            return this;
        }

        Builder enableLocalSessionStore() {
            LocalHttpSessionHandler sessionHandler = new LocalHttpSessionHandler(_httpOptions);
            _currentRouter = _routerManager.register();
            version(HUNT_HTTP_DEBUG) tracef("routeid: %d, paths: *", _currentRouter.getId());
            _currentRouter.path("*").handler(sessionHandler);
            return this;
        }

        private void handlerWrap(RouteHandler handler, RoutingContext ctx) {
            try {
                if(handler !is null) handler.handle(ctx);
            } catch (Exception ex) {
                errorf("route handler exception: %s", ex.msg);
                version(HUNT_HTTP_DEBUG) error(ex);
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

        private void handlerWrap(RoutingHandler handler, RoutingContext ctx) {
            try {
                if(handler !is null) handler(ctx);
            } catch (Exception ex) {
                errorf("route handler exception: %s", ex.msg);
                version(HUNT_DEBUG) error(ex);
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

    
version(WITH_HUNT_TRACE) {
        private string _localServiceName;
        private bool _isB3HeaderRequired = true;
        // private TracingOptions _tracingOptions;

        Builder localServiceName(string name) {
            _localServiceName = name;
            return this;
        }

        Builder isB3HeaderRequired(bool flag) {
            _isB3HeaderRequired = flag;
            return this;
        }

        private void initializeTracer(HttpRequest request, HttpConnection connection) {
            Tracer tracer;
            string reqPath = request.getURI().getPath();
            string b3 = request.header("b3");
            if(b3.empty()) {
                if(_isB3HeaderRequired) return;

                tracer = new Tracer(reqPath);
            } else {
                version(HUNT_HTTP_DEBUG) {
                    warningf("initializing tracer for %s, with %s", reqPath, b3);
                }

                tracer = new Tracer(reqPath, b3);
            }

            Span span = tracer.root;
            span.initializeLocalEndpoint(_localServiceName);
            import std.socket;

            // 
            Address remote = connection.getRemoteAddress;
            EndPoint remoteEndpoint = new EndPoint();
            remoteEndpoint.ipv4 = remote.toAddrString();
            remoteEndpoint.port = remote.toPortString().to!int;
            span.remoteEndpoint = remoteEndpoint;
            //

            span.start();
            request.tracer = tracer;
        }

        private void endTraceSpan(HttpRequest request, int status, string message = null) {
            Tracer tracer = request.tracer;
            if(tracer is null) {
                version(HUNT_TRACE_DEBUG) warning("no tracer found");
                return;
            }

            HttpURI uri = request.getURI();
            string[string] tags;
            tags[HTTP_HOST] = uri.getHost();
            tags[HTTP_URL] = uri.getPathQuery();
            tags[HTTP_PATH] = uri.getPath();
            tags[HTTP_REQUEST_SIZE] = request.getContentLength().to!string();
            tags[HTTP_METHOD] = request.getMethod();

            Span span = tracer.root;
            if(span !is null) {
                tags[HTTP_STATUS_CODE] = to!string(status);
                traceSpanAfter(span, tags, message);
                httpSender().sendSpans(span);
            }
        }    
}  
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
                    version(WITH_HUNT_TRACE) initializeTracer(serverRequest, connection);

                    HttpServerContext context = new HttpServerContext(
                        serverRequest, cast(HttpServerResponse)response, 
                        ot, cast(HttpServerConnection)connection);

                    serverRequest.onHeaderComplete();
                    dispatchRoute(context);
                    
                    // request.setAttachment(context);

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
                    version(HUNT_HTTP_DEBUG) info("end of a request on ", request.getURI().getPath());
                    version(WITH_HUNT_TRACE) endTraceSpan(request, response.getStatus());
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

                    version(WITH_HUNT_TRACE) endTraceSpan(request, status, reason);
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
                WebSocketMessageHandler handler = _webSocketHandlers.get(path, null);
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
                WebSocketMessageHandler handler = _webSocketHandlers.get(path, null);
                if(handler !is null)
                    handler.onOpen(connection);
            })
            .onFrame((WebSocketFrame frame, WebSocketConnection connection) {
                string path = connection.getPath();
                WebSocketMessageHandler handler = _webSocketHandlers.get(path, null);
                if(handler is null) {
                    return;
                }

                switch (frame.getType()) {
                    case WebSocketFrameType.TEXT:
                        handler.onText(connection, (cast(DataFrame) frame).getPayloadAsUTF8());
                        break;
                        
                    case WebSocketFrameType.BINARY:
                        handler.onBinary(connection, frame.getPayload());
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
                        handler.onContinuation(connection, frame.getPayload());
                        break;

                    default: break;
                }
            })
            .onError((Exception ex, WebSocketConnection connection) {
                string path = connection.getPath();
                WebSocketMessageHandler handler = _webSocketHandlers.get(path, null);
                if(handler !is null)
                    handler.onError(connection, ex);
            });

            return adapter;
        }

        private void dispatchRoute(HttpServerContext context) {
            bool isHandled = false;
            if(_hostManagerGroup.length > 0) {
                HttpServerRequest request = context.httpRequest();
                string host = request.host();
                if(!host.empty()) {
                    host = split(host, ":")[0];
                    auto itemPtr = host in _hostManagerGroup;
                    if(itemPtr !is null) {
                        isHandled = true;
                        itemPtr.accept(context);
                        version(HUNT_HTTP_DEBUG) {
                            tracef("host group, host: %s, path: %s", host, request.path());
                        }
                    }
                }
            }
            
            if(_pathManagerGroup.length > 0) {
                HttpServerRequest request = context.httpRequest();
                string path = request.originalPath();
                // if(path.length > 1 && path[$-1] != '/') {
                //     path ~= "/";
                // }

                string groupPath = split(path, "/")[1];

                // warningf("full path: %s, group path: %s", path, groupPath);
                auto itemPtr = groupPath in _pathManagerGroup;
                if(itemPtr !is null) {
                    isHandled = true;
                    path = path[groupPath.length + 1 .. $]; // skip the group path
                    version(HUNT_HTTP_DEBUG) {
                        tracef("full path: %s, group path: %s, new path: %s", request.path(), groupPath, path);
                    }

                    request.path = path; // Reset the rquest path
                    itemPtr.accept(context);
                    version(HUNT_HTTP_DEBUG_MORE) {
                        tracef("path group, original path: %s, revised path: %s, group path: %s", 
                            request.originalPath(), request.path(), groupPath);
                    }
                }
            } 

            if(!isHandled) {
                _routerManager.accept(context);
            }
        }

        /* ---------------------------- Options operation --------------------------- */

        Builder maxRequestSize(int size) {
            _httpOptions.requestOptions.setMaxRequestSize(size);
            return this;
        }

        HttpServer build() { 

            string basePath = dirName(thisExePath);

            if(!_tlsCertificate.empty()) {
                PemKeyCertOptions certOptions = new PemKeyCertOptions(buildPath(basePath, _tlsCertificate),
                    buildPath(basePath, _tlsPrivateKey), _tlsCertPassword, _tlsKeyPassword);
                
                if(!_tlsCaFile.empty()) {
                    certOptions.setCaFile(buildPath(basePath, _tlsCaFile));
                    certOptions.setCaPassword(_tlsCaPassworld);
                }
                _httpOptions.setKeyCertOptions(certOptions);
            }

            _httpOptions.setSecureConnectionEnabled(_isCertificateAuth);

            return new HttpServer(_httpOptions, buildServerHttpHandler(), buildWebSocketHandler());
        }
    }
}
