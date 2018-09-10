module hunt.http.server.http.router.RouterManager;

import hunt.http.server.http.router.Matcher;
import hunt.http.server.http.router.Router;

import hunt.http.server.http.router.RequestAcceptor;

import hunt.http.server.http.router.handler.HttpBodyHandler;
import hunt.http.server.http.router.handler.DefaultErrorResponseHandlerLoader;
import hunt.http.server.http.router.impl.RouterManagerImpl;

import hunt.container;
import hunt.util.common;
import hunt.util.exception;


class RouterMatchResult : Comparable!RouterMatchResult {

    private Router router;
    private Map!(string, string) parameters;
    private Set!(Matcher.MatchType)matchTypes;

    this(Router router, Map!(string, string) parameters, Set!(Matcher.MatchType)matchTypes) {
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

    override
    int opCmp(Object o)
    {
        RouterMatchResult r = cast(RouterMatchResult)o;
        if(o is null)
            throw new NullPointerException();
        return opCmp(r);
    }

    int opCmp(RouterMatchResult o) {
        return router.opCmp(o.getRouter());
    }

    override
    bool opEquals(Object o) {
        if (this is o) return true;
        if (o is null || typeid(this) != typeid(o)) return false;
        RouterMatchResult that = cast(RouterMatchResult) o;
        return router == that.router;
    }

    override
    size_t toHash() @trusted nothrow {
        return hashOf(router);
    }
}


/**
 * 
 */
interface RouterManager : RequestAcceptor {

    enum DEFAULT_LAST_ROUTER_ID = int.max / 2;

    Router register();

    Router register(int id);

    NavigableSet!(RouterMatchResult) findRouter(string method, string path, string contentType, string accept);

    static RouterManager create() {
        return create(new HttpBodyConfiguration());
    }

    static RouterManager create(HttpBodyConfiguration configuration) {
        RouterManagerImpl routerManager = new RouterManagerImpl();
        routerManager.register().path("*").handler(new HttpBodyHandler(configuration));
        routerManager.register(DEFAULT_LAST_ROUTER_ID).path("*").handler(DefaultErrorResponseHandlerLoader.getInstance().getHandler());
        return routerManager;
    }
}
