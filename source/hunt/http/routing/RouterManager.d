module hunt.http.routing.RouterManager;

import hunt.http.routing.handler;
import hunt.http.routing.Matcher;
import hunt.http.routing.Router;
import hunt.http.routing.impl.RouterManagerImpl;

import hunt.http.server.HttpRequestOptions;
import hunt.http.server.HttpServerContext;

import hunt.collection;
import hunt.Exceptions;
import hunt.util.Common;

/**
 * 
 */
enum RouteGroupType {
    Default,
    Host,
    Path
}

enum DEFAULT_LAST_ROUTER_ID = int.max / 2;

/**
 * 
 */
interface RouterManager {

    Router register();

    Router register(int id);

    NavigableSet!(RouterMatchResult) findRouter(string method, string path,
            string contentType, string accept);

    void accept(HttpServerContext context);

    // static RouterManager create() {
    //     return create(new HttpRequestOptions());
    // }

    static RouterManager create() {
        RouterManagerImpl routerManager = new RouterManagerImpl();

        routerManager.register().path("*").handler(new DefaultRouteHandler());

        Router currentRouter = routerManager.register(DEFAULT_LAST_ROUTER_ID);
        currentRouter.path("*")
            .handler(ErrorResponseHandler.Default());
        
        version(HUNT_HTTP_DEBUG) {
            import hunt.logging;
            tracef("routeid: %d, paths: *", currentRouter.getId());
        }
        
        return routerManager;
    }
}

/**
 * 
 */
class RouterMatchResult : Comparable!RouterMatchResult {

    private Router router;
    private Map!(string, string) parameters;
    private Set!(Matcher.MatchType) matchTypes;

    this(Router router, Map!(string, string) parameters, Set!(Matcher.MatchType) matchTypes) {
        this.router = router;
        this.parameters = parameters;
        this.matchTypes = matchTypes;
    }

    Router getRouter() {
        return router;
    }

    Map!(string, string) getParameters() {
        return parameters;
    }

    Set!(Matcher.MatchType) getMatchTypes() {
        return matchTypes;
    }

    override int opCmp(Object o) {
        RouterMatchResult r = cast(RouterMatchResult) o;
        if (o is null)
            throw new NullPointerException();
        return opCmp(r);
    }

    int opCmp(RouterMatchResult o) {
        return router.opCmp(o.getRouter());
    }

    override bool opEquals(Object o) {
        if (this is o)
            return true;
        if (o is null || typeid(this) != typeid(o))
            return false;
        RouterMatchResult that = cast(RouterMatchResult) o;
        return router == that.router;
    }

    override size_t toHash() @trusted nothrow {
        return hashOf(router);
    }
}
