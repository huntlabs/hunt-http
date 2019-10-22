module hunt.http.routing.handler.LocalHttpSessionHandler;

import hunt.http.routing.RoutingContext;
import hunt.http.routing.impl.HttpSessionHandlerImpl;
import hunt.http.routing.impl.RoutingContextImpl;

import hunt.http.server.HttpServerOptions;
import hunt.http.server.HttpSession;
import hunt.http.server.LocalSessionStore;

import hunt.util.Lifecycle;

/** 
 * 
 */
class LocalHttpSessionHandler : AbstractLifecycle, RouteHandler {

    private SessionStore sessionStore;
    private HttpServerOptions _options;

    // this() {
    //     this(new HttpSessionConfiguration());
    //     sessionStore = new LocalSessionStore();
    // }

    this(HttpServerOptions options) {
        _options = options;
        sessionStore = new LocalSessionStore();
        start();
    }

    override
    void handle(RoutingContext context) {
        RoutingContextImpl ctx = cast(RoutingContextImpl) context;
        HttpSessionHandlerImpl sessionHandler = new HttpSessionHandlerImpl(context, sessionStore,
            _options.getSessionIdParameterName(), _options.getDefaultMaxInactiveInterval());
        ctx.setHttpSessionHandler(sessionHandler);
        context.next();
    }

    SessionStore getSessionStore() {
        return sessionStore;
    }

    // HttpServerOptions getConfiguration() {
    //     return configuration;
    // }

    override
    protected void initialize() {

    }

    override
    protected void destroy() {
        sessionStore.stop();
    }
}
