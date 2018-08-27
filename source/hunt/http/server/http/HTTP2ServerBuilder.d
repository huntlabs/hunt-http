module hunt.http.server.http.HTTP2ServerBuilder;

import hunt.http.server.http.SimpleHTTPServer;
import hunt.http.server.http.SimpleHTTPServerConfiguration;

import hunt.http.codec.http.model.BadMessageException;
import hunt.http.codec.http.model.HttpMethod;
// import hunt.http.codec.websocket.frame.Frame;
// import hunt.http.codec.websocket.stream.AbstractWebSocketBuilder;
// import hunt.http.codec.websocket.stream.WebSocketConnection;
import hunt.net.secure.SecureSessionFactory;

import hunt.http.server.http.router.handler;
import hunt.http.server.http.router.Router;
import hunt.http.server.http.router.RouterManager;
import hunt.http.server.http.router.RoutingContext;
import hunt.http.server.http.router.impl.RoutingContextImpl;

import hunt.util.functional;
import hunt.util.exception;

import hunt.container.ByteBuffer;
import hunt.container.Collections;

import hunt.logging;

/**
 * 
 */
class HTTP2ServerBuilder {

    private RoutingContext currentCtx; 

    private SimpleHTTPServer server;
    private RouterManager routerManager;
    private Router currentRouter;
    // private List!WebSocketBuilder webSocketBuilders; 

    this()
    {
        // webSocketBuilders = new LinkedList!WebSocketBuilder();
    }

    HTTP2ServerBuilder httpsServer() {
        SimpleHTTPServerConfiguration configuration = new SimpleHTTPServerConfiguration();
        configuration.setSecureConnectionEnabled(true);
        return httpServer(configuration, new HTTPBodyConfiguration());
    }

    HTTP2ServerBuilder httpsServer(SecureSessionFactory secureSessionFactory) {
        SimpleHTTPServerConfiguration configuration = new SimpleHTTPServerConfiguration();
        configuration.setSecureConnectionEnabled(true);
        configuration.setSecureSessionFactory(secureSessionFactory);
        return httpServer(configuration, new HTTPBodyConfiguration());
    }

    HTTP2ServerBuilder httpServer() {
        return httpServer(new SimpleHTTPServerConfiguration(), new HTTPBodyConfiguration());
    }

    HTTP2ServerBuilder httpServer(SimpleHTTPServerConfiguration serverConfiguration,
                                         HTTPBodyConfiguration httpBodyConfiguration) {
        AbstractErrorResponseHandler handler = DefaultErrorResponseHandlerLoader.getInstance().getHandler();
        server = new SimpleHTTPServer(serverConfiguration);
        server.badMessage((status, reason, request) {
            RoutingContext ctx = new RoutingContextImpl(request, Collections.emptyNavigableSet!(RouterMatchResult)());
            handler.render(ctx, status, new BadMessageException(reason));
        });
        routerManager = RouterManager.create(httpBodyConfiguration);
        return this;
    }

    SimpleHTTPServer getServer() {
        return server;
    }

    /**
     * register a new router
     *
     * @return HTTP2ServerBuilder
     */
    HTTP2ServerBuilder router() {
        currentRouter = routerManager.register();
        return this;
    }

    HTTP2ServerBuilder router(int id) {
        currentRouter = routerManager.register(id);
        return this;
    }

    private void check() {
        if (server is null) {
            throw new IllegalStateException("the http server has not been created, please call httpServer() first");
        }
    }


    HTTP2ServerBuilder useCertificateFile(string certificate, string privateKey ) {
        check();
        SimpleHTTPServerConfiguration config = server.getConfiguration();

        import hunt.net.secure.conscrypt.AbstractConscryptSSLContextFactory;
        FileCredentialConscryptSSLContextFactory fc = 
            new FileCredentialConscryptSSLContextFactory(certificate, privateKey, "hunt2018", "hunt2018");
        config.getSecureSessionFactory.setServerSSLContextFactory = fc; 
        return this;
    }

    HTTP2ServerBuilder listen(string host, int port) {
        check();
        server.headerComplete( (req) { routerManager.accept(req); }).listen(host, port);
        return this;
    }

    HTTP2ServerBuilder listen() {
        check();
        server.headerComplete( (req) { routerManager.accept(req); }).listen();
        return this;
    }

    HTTP2ServerBuilder stop() {
        check();
        server.stop();
        return this;
    }

    // delegated Router methods
    HTTP2ServerBuilder path(string url) {
        currentRouter.path(url);
        return this;
    }

    HTTP2ServerBuilder paths(string[] paths) {
        currentRouter.paths(paths);
        return this;
    }

    HTTP2ServerBuilder pathRegex(string regex) {
        currentRouter.pathRegex(regex);
        return this;
    }

    HTTP2ServerBuilder method(string method) {
        currentRouter.method(method);
        return this;
    }

    HTTP2ServerBuilder methods(string[] methods) {
        foreach(string m; methods)
            this.method(m);
        return this;
    }

    HTTP2ServerBuilder method(HttpMethod httpMethod) {
        currentRouter.method(httpMethod);
        return this;
    }

    HTTP2ServerBuilder methods(HttpMethod[] methods) {
        foreach(HttpMethod m; methods)
            this.method(m);
        return this;
    }

    HTTP2ServerBuilder get(string url) {
        currentRouter.get(url);
        return this;
    }

    HTTP2ServerBuilder post(string url) {
        currentRouter.post(url);
        return this;
    }

    HTTP2ServerBuilder put(string url) {
        currentRouter.put(url);
        return this;
    }

    HTTP2ServerBuilder del(string url) {
        currentRouter.del(url);
        return this;
    }

    HTTP2ServerBuilder consumes(string contentType) {
        currentRouter.consumes(contentType);
        return this;
    }

    HTTP2ServerBuilder produces(string accept) {
        currentRouter.produces(accept);
        return this;
    }

    HTTP2ServerBuilder handler(RoutingHandler handler) {
        // currentRouter.handler( (RoutingContext ctx) { handlerWrap(handler, ctx); });
        currentRouter.handler( new class Handler {
             void handle(RoutingContext ctx) { handlerWrap(handler, ctx); }
        });
        return this;
    }

    protected void handlerWrap(RoutingHandler handler, RoutingContext ctx) {
        try {
            currentCtx = ctx;
            handler(ctx);
        } catch (Exception e) {
            ctx.fail(e);
            errorf("http server handler exception", e);
        } finally {
            currentCtx = null;
        }
    }

    // HTTP2ServerBuilder asyncHandler(Handler handler) {
    //     currentRouter.handler(ctx -> {
    //         ctx.getResponse().setAsynchronous(true);
    //         server.getHandlerExecutorService().execute(() -> handlerWrap(handler, ctx));
    //     });
    //     return this;
    // }

    // WebSocketBuilder webSocket(string path) {
    //     WebSocketBuilder webSocketBuilder = new WebSocketBuilder(path);
    //     webSocketBuilders.add(webSocketBuilder);
    //     return webSocketBuilder;
    // }

    // class WebSocketBuilder : AbstractWebSocketBuilder {
    //     protected final string path;
    //     protected Action1<WebSocketConnection> onConnect;

    //     WebSocketBuilder(string path) {
    //         this.path = path;
    //     }

    //     WebSocketBuilder onConnect(Action1<WebSocketConnection> onConnect) {
    //         this.onConnect = onConnect;
    //         return this;
    //     }

    //     WebSocketBuilder onText(Action2<string, WebSocketConnection> onText) {
    //         super.onText(onText);
    //         return this;
    //     }

    //     WebSocketBuilder onData(Action2<ByteBuffer, WebSocketConnection> onData) {
    //         super.onData(onData);
    //         return this;
    //     }

    //     WebSocketBuilder onError(Action2<Throwable, WebSocketConnection> onError) {
    //         super.onError(onError);
    //         return this;
    //     }

    //     HTTP2ServerBuilder listen(string host, int port) {
    //         return HTTP2ServerBuilder.this.listen(host, port);
    //     }

    //     HTTP2ServerBuilder listen() {
    //         return HTTP2ServerBuilder.this.listen();
    //     }

    //     private HTTP2ServerBuilder listenWebSocket() {
    //         server.registerWebSocket(path, new WebSocketHandler() {

    //             override
    //             void onConnect(WebSocketConnection webSocketConnection) {
    //                 Optional.ofNullable(onConnect).ifPresent(c -> c.call(webSocketConnection));
    //             }

    //             override
    //             void onFrame(Frame frame, WebSocketConnection connection) {
    //                 WebSocketBuilder.this.onFrame(frame, connection);
    //             }

    //             override
    //             void onError(Throwable t, WebSocketConnection connection) {
    //                 WebSocketBuilder.this.onError(t, connection);
    //             }
    //         });
    //         router().path(path).handler(ctx -> {
    //         });
    //         return HTTP2ServerBuilder.this;
    //     }

    // }

    // static Optional<RoutingContext> getCurrentCtx() {
    //     return Optional.ofNullable(currentCtx.get());
    // }
}
