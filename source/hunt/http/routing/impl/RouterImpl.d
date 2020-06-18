module hunt.http.routing.impl.RouterImpl;

import hunt.http.routing.Router;
import hunt.http.routing.RoutingContext;

import hunt.http.HttpMethod;
import hunt.http.routing.Matcher;
import hunt.http.routing.Router;

import hunt.http.routing.impl.RouterManagerImpl;

import hunt.collection;
import hunt.logging.ConsoleLogger;
import hunt.Exceptions;
import hunt.text;
import hunt.util.Comparator;

import std.algorithm;
import std.array;
import std.conv;
import std.path;
import std.string;

alias MatchType = Matcher.MatchType;
alias MatchResult = Matcher.MatchResult;

/**
 * 
 */
class RouterImpl : Router {

    private int id;
    private RouterManagerImpl routerManager;
    private Set!(MatchType) matchTypes;

    // private RouteHandler _handler;
    private RoutingHandler _routingHandler;
    private bool _isEnable = true;
    private List!(string) urlList;

    this(int id, RouterManagerImpl routerManager) {
        this.id = id;
        this.routerManager = routerManager;
        matchTypes = new HashSet!(MatchType)();
        urlList = new ArrayList!(string)();
    }

    override
    Router path(string url) {
        url = url.strip();
        checkPath(url);

        if (url.length == 1) {
            switch (url.charAt(0)) {
                case '/':
                    routerManager.getPrecisePathMather().add(url, this);
                    break;
                case '*':
                    routerManager.getPatternPathMatcher().add(url, this);
                    break;
                default:
                    throw new IllegalArgumentException("the url: [" ~ url ~ "] format error");
            }
        } else {
            if (url.charAt(0) != '/') {
                throw new IllegalArgumentException("the path must start with '/'");
            }

            if (url.canFind("*")) {
                routerManager.getPatternPathMatcher().add(url, this);
            } else {
                if (url[$ -1] != '/') {
                    url = url ~ "/";
                }

                string[] paths =  std.path.pathSplitter(url).array; // PathUtils.split(url);
                if (isParameterPath(paths)) {
                    routerManager.getParameterPathMatcher().add(url, this);
                } else {
                    routerManager.getPrecisePathMather().add(url, this);
                }
            }
        }
        urlList.add(url);
        matchTypes.add(MatchType.PATH);
        return this;
    }

    override
    Router paths(string[] urlList) {
        foreach(string u; urlList) {
            this.path(u);
        }

        return this;
    }

    private void checkPath(string url) {
        if (url.empty()) {
            throw new IllegalArgumentException("the url is empty");
        }

        if (urlList.contains(url)) {
            throw new IllegalArgumentException("the url " ~ url ~ " exists");
        }
    }

    private bool isParameterPath(string[] paths) {
        foreach (string p ; paths) {
            version(HUNT_HTTP_DEBUG_MORE) trace("path: ", p);
            if (p[0] == ':' || p[0] == '{') {
                return true;
            }
        }
        return false;
    }

    override
    Router pathRegex(string regex) {
        checkPath(regex);
        regex = regex.strip();
        routerManager.getRegexPathMatcher().add(regex, this);
        urlList.add(regex);
        matchTypes.add(MatchType.PATH);
        return this;
    }

    override
    Router method(HttpMethod httpMethod) {
        return method(httpMethod.asString());
    }

    override
    Router method(string method) {
        routerManager.getHttpMethodMatcher().add(method, this);
        matchTypes.add(MatchType.METHOD);
        return this;
    }

    override
    Router get(string url) {
        return method(HttpMethod.GET).path(url);
    }

    override
    Router post(string url) {
        return method(HttpMethod.POST).path(url);
    }

    override
    Router put(string url) {
        return method(HttpMethod.PUT).path(url);
    }

    override
    Router del(string url) {
        return method(HttpMethod.DELETE).path(url);
    }

    override
    Router consumes(string contentType) {
        // if (!contentType.canFind("*")) {
        //     routerManager.getContentTypePreciseMatcher().add(contentType, this);
        // } else {
        //     routerManager.getContentTypePatternMatcher().add(contentType, this);
        // }
        // matchTypes.add(MatchType.CONTENT_TYPE);
        return this;
    }

    override
    Router produces(string accept) {
        // routerManager.getAcceptHeaderMatcher().add(accept, this);
        // matchTypes.add(MatchType.ACCEPT);
        return this;
    }

    Router handler(RouteHandler handler) {
        if(handler !is null)  {
            this._routingHandler = (RoutingContext ctx) {
                version(HUNT_HTTP_DEBUG) trace("Current route handler: ", typeid(cast(Object)handler));
                handler.handle(ctx); 
            };
        } else {
            version(HUNT_HTTP_DEBUG) warning("The handler is null");
        }
        return this;
    }

    Router handler(RoutingHandler h) {
        assert(h !is null);
        this._routingHandler = h;
        return this;
    }

    void handle(RoutingContext context) {
        if(_routingHandler !is null) {
            _routingHandler(context);
        }
    }

    override
    Router enable() {
        _isEnable = true;
        return this;
    }

    override
    Router disable() {
        _isEnable = false;
        return this;
    }

    override
    int getId() {
        return id;
    }

    override
    bool isEnable() {
        return _isEnable;
    }

    override
    Set!(MatchType) getMatchTypes() {
        return matchTypes;
    }

    // RouteHandler getHandler() {
    //     return _handler;
    // }

    int opCmp(Router o) {
        return compare(id, o.getId());
    }

    override int opCmp(Object o) {
        Router r = cast(Router)o;
        if(r is null)
                throw new NullPointerException();
        return opCmp(r);
    }


    override
    bool opEquals(Object o) {
        if (this is o) return true;
        RouterImpl router = cast(RouterImpl) o;
        if(router is null)
            return false;
        return id == router.id;
    }

    override
    size_t toHash() @trusted nothrow {
        return hashOf(id);
    }

    override
    string toString() {
        return "Router {id=" ~ id.to!string() ~
                ", matchTypes=" ~ matchTypes.toString() ~
                ", url=" ~ urlList.toString() ~ "}";
    }
}
