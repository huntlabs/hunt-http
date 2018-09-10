module hunt.http.server.http.Http2ServerBuilder;

import hunt.http.server.http.SimpleHttpServer;
import hunt.http.server.http.SimpleHttpServerConfiguration;

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
class Http2ServerBuilder {

    private RoutingContext currentCtx; 

    private SimpleHttpServer server;
    private RouterManager routerManager;
    private Router currentRouter;
    // private List!WebSocketBuilder webSocketBuilders; 

    this()
    {
        // webSocketBuilders = new LinkedList!WebSocketBuilder();
    }

    Http2ServerBuilder httpsServer() {
        SimpleHttpServerConfiguration configuration = new SimpleHttpServerConfiguration();
        configuration.setSecureConnectionEnabled(true);
        return httpServer(configuration, new HttpBodyConfiguration());
    }

    Http2ServerBuilder httpsServer(SecureSessionFactory secureSessionFactory) {
        SimpleHttpServerConfiguration configuration = new SimpleHttpServerConfiguration();
        configuration.setSecureConnectionEnabled(true);
        configuration.setSecureSessionFactory(secureSessionFactory);
        return httpServer(configuration, new HttpBodyConfiguration());
    }

    Http2ServerBuilder httpServer() {
        return httpServer(new SimpleHttpServerConfiguration(), new HttpBodyConfiguration());
    }

    Http2ServerBuilder httpServer(SimpleHttpServerConfiguration serverConfiguration,
                                         HttpBodyConfiguration httpBodyConfiguration) {
        AbstractErrorResponseHandler handler = DefaultErrorResponseHandlerLoader.getInstance().getHandler();
        server = new SimpleHttpServer(serverConfiguration);
        server.badMessage((status, reason, request) {
            RoutingContext ctx = new RoutingContextImpl(request, Collections.emptyNavigableSet!(RouterMatchResult)());
            handler.render(ctx, status, new BadMessageException(reason));
        });
        routerManager = RouterManager.create(httpBodyConfiguration);
        return this;
    }

    SimpleHttpServer getServer() {
        return server;
    }

    /**
     * register a new router
     *
     * @return Http2ServerBuilder
     */
    Http2ServerBuilder router() {
        currentRouter = routerManager.register();
        return this;
    }

    Http2ServerBuilder router(int id) {
        currentRouter = routerManager.register(id);
        return this;
    }

    private void check() {
        if (server is null) {
            throw new IllegalStateException("the http server has not been created, please call httpServer() first");
        }
    }


    Http2ServerBuilder useCertificateFile(string certificate, string privateKey ) {
        check();
        SimpleHttpServerConfiguration config = server.getConfiguration();

        import hunt.net.secure.conscrypt.AbstractConscryptSSLContextFactory;
        FileCredentialConscryptSSLContextFactory fc = 
            new FileCredentialConscryptSSLContextFactory(certificate, privateKey, "hunt2018", "hunt2018");
        config.getSecureSessionFactory.setServerSSLContextFactory = fc; 
        return this;
    }

    Http2ServerBuilder listen(string host, int port) {
        check();
        server.headerComplete( (req) { routerManager.accept(req); }).listen(host, port);
        return this;
    }

    Http2ServerBuilder listen() {
        check();
        server.headerComplete( (req) { routerManager.accept(req); }).listen();
        return this;
    }

    Http2ServerBuilder stop() {
        check();
        server.stop();
        return this;
    }

    // delegated Router methods
    Http2ServerBuilder path(string url) {
        currentRouter.path(url);
        return this;
    }

    Http2ServerBuilder paths(string[] paths) {
        currentRouter.paths(paths);
        return this;
    }

    Http2ServerBuilder pathRegex(string regex) {
        currentRouter.pathRegex(regex);
        return this;
    }

    Http2ServerBuilder method(string method) {
        currentRouter.method(method);
        return this;
    }

    Http2ServerBuilder methods(string[] methods) {
        foreach(string m; methods)
            this.method(m);
        return this;
    }

    Http2ServerBuilder method(HttpMethod httpMethod) {
        currentRouter.method(httpMethod);
        return this;
    }

    Http2ServerBuilder methods(HttpMethod[] methods) {
        foreach(HttpMethod m; methods)
            this.method(m);
        return this;
    }

    Http2ServerBuilder get(string url) {
        currentRouter.get(url);
        return this;
    }

    Http2ServerBuilder post(string url) {
        currentRouter.post(url);
        return this;
    }

    Http2ServerBuilder put(string url) {
        currentRouter.put(url);
        return this;
    }

    Http2ServerBuilder del(string url) {
        currentRouter.del(url);
        return this;
    }

    Http2ServerBuilder consumes(string contentType) {
        currentRouter.consumes(contentType);
        return this;
    }

    Http2ServerBuilder produces(string accept) {
        currentRouter.produces(accept);
        return this;
    }

    Http2ServerBuilder handler(RoutingHandler handler) {
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

    // Http2ServerBuilder asyncHandler(Handler handler) {
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

    //     Http2ServerBuilder listen(string host, int port) {
    //         return Http2ServerBuilder.this.listen(host, port);
    //     }

    //     Http2ServerBuilder listen() {
    //         return Http2ServerBuilder.this.listen();
    //     }

    //     private Http2ServerBuilder listenWebSocket() {
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
    //         return Http2ServerBuilder.this;
    //     }

    // }

    // static Optional<RoutingContext> getCurrentCtx() {
    //     return Optional.ofNullable(currentCtx.get());
    // }
}
