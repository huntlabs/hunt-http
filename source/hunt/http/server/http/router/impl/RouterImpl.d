module hunt.http.server.http.router.impl.RouterImpl;

import hunt.http.server.http.router.Router;

import hunt.http.codec.http.model.HttpMethod;
import hunt.http.server.http.router.Handler;
import hunt.http.server.http.router.Matcher;
import hunt.http.server.http.router.Router;

import hunt.http.server.http.router.impl.RouterManagerImpl;

import hunt.container;
import hunt.util.exception;
import hunt.util.string;

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

    private Handler _handler;
    private bool _isEnable = true;
    private List!(string) urlList; // = new ArrayList!(string)();

    this(int id, RouterManagerImpl routerManager) {
        this.id = id;
        this.routerManager = routerManager;
        matchTypes = new HashSet!(MatchType)();
        urlList = new ArrayList!(string)();
    }

    override
    Router path(string url) {
        checkPath(url);
        url = url.strip();

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
        // urlList.forEach(this::path);
        foreach(string u; urlList)
            this.path(u);

        return this;
    }

    private void checkPath(string url) {
        if (url is null) {
            throw new IllegalArgumentException("the url is empty");
        }

        if (urlList.contains(url.strip())) {
            throw new IllegalArgumentException("the url " ~ url ~ " exists");
        }
    }

    private bool isParameterPath(string[] paths) {
        foreach (string p ; paths) {
            if (p.charAt(0) == ':') {
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
        if (!contentType.canFind("*")) {
            routerManager.getContentTypePreciseMatcher().add(contentType, this);
        } else {
            routerManager.getContentTypePatternMatcher().add(contentType, this);
        }
        matchTypes.add(MatchType.CONTENT_TYPE);
        return this;
    }

    override
    Router produces(string accept) {
        routerManager.getAcceptHeaderMatcher().add(accept, this);
        matchTypes.add(MatchType.ACCEPT);
        return this;
    }

    override
    Router handler(Handler h) {
        this._handler = h;
        return this;
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

    Handler getHandler() {
        return _handler;
    }

    override
    int compareTo(Router o) {
        return compare(id, o.getId());
    }

    static int compare(int x, int y) {
        return (x < y) ? -1 : ((x == y) ? 0 : 1);
    }

    override
    bool opEquals(Object o) {
        if (this is o) return true;
        if (o is null || typeid(this) !is typeid(o)) return false;
        RouterImpl router = cast(RouterImpl) o;
        return id == router.id;
    }

    override
    size_t toHash() @trusted nothrow {
        return hashOf(id);
    }

    override
    string toString() {
        return "Router {" ~
                "id=" ~ id.to!string() ~
                ", matchTypes=" ~ matchTypes.toString() ~
                ", url=" ~ urlList.toString() ~
                '}';
    }
}
