module hunt.http.routing.impl.RouterManagerImpl;

import hunt.http.routing.impl.ContentTypePreciseMatcher;
import hunt.http.routing.impl.ContentTypePatternMatcher;
import hunt.http.routing.impl.AcceptHeaderMatcher;
import hunt.http.routing.impl.HttpMethodMatcher;
import hunt.http.routing.impl.PatternPathMatcher;
import hunt.http.routing.impl.PrecisePathMatcher;
import hunt.http.routing.impl.ParameterPathMatcher;
import hunt.http.routing.impl.RegexPathMatcher;
import hunt.http.routing.impl.RouterImpl;
import hunt.http.routing.impl.RoutingContextImpl;

import hunt.http.HttpHeader;
import hunt.http.HttpMethod;
import hunt.http.HttpRequest;

import hunt.http.server.HttpServerContext;
import hunt.http.routing.Matcher;
import hunt.http.routing.Router;
import hunt.http.routing.RouterManager;
import hunt.http.routing.RoutingContext;

import hunt.collection;

import hunt.Exceptions;

import hunt.logging;

/**
 * 
 */
class RouterManagerImpl : RouterManager {

    private int idGenerator;
    private Map!(Matcher.MatchType, List!(Matcher)) matcherMap;
    private Matcher precisePathMather;
    private Matcher patternPathMatcher;
    private Matcher regexPathMatcher;
    private Matcher parameterPathMatcher;
    private Matcher httpMethodMatcher;
    // private Matcher contentTypePreciseMatcher;
    // private Matcher contentTypePatternMatcher;
    // private Matcher acceptHeaderMatcher;

    this() {
        matcherMap = new HashMap!(Matcher.MatchType, List!(Matcher))();
        precisePathMather = new PrecisePathMatcher();
        patternPathMatcher = new PatternPathMatcher();
        parameterPathMatcher = new ParameterPathMatcher();
        regexPathMatcher = new RegexPathMatcher();
        ArrayList!Matcher al = new ArrayList!Matcher([precisePathMather, patternPathMatcher, parameterPathMatcher, regexPathMatcher]);
        matcherMap.put(Matcher.MatchType.PATH, al);

        httpMethodMatcher = new HttpMethodMatcher();
        matcherMap.put(Matcher.MatchType.METHOD, Collections.singletonList!(Matcher)(httpMethodMatcher));

        // contentTypePreciseMatcher = new ContentTypePreciseMatcher();
        // contentTypePatternMatcher = new ContentTypePatternMatcher();
        // al = new ArrayList!Matcher([contentTypePreciseMatcher, contentTypePatternMatcher]);
        // matcherMap.put(Matcher.MatchType.CONTENT_TYPE, al);

        // acceptHeaderMatcher = new AcceptHeaderMatcher();
        // matcherMap.put(Matcher.MatchType.ACCEPT, Collections.singletonList!(Matcher)(acceptHeaderMatcher));
    }

    Matcher getHttpMethodMatcher() {
        return httpMethodMatcher;
    }

    Matcher getPrecisePathMather() {
        return precisePathMather;
    }

    Matcher getPatternPathMatcher() {
        return patternPathMatcher;
    }

    Matcher getRegexPathMatcher() {
        return regexPathMatcher;
    }

    Matcher getParameterPathMatcher() {
        return parameterPathMatcher;
    }

    // Matcher getContentTypePreciseMatcher() {
    //     return contentTypePreciseMatcher;
    // }

    // Matcher getContentTypePatternMatcher() {
    //     return contentTypePatternMatcher;
    // }

    // Matcher getAcceptHeaderMatcher() {
    //     return acceptHeaderMatcher;
    // }

    override NavigableSet!RouterMatchResult findRouter(string method, 
            string path, string contentType, string accept) {

        Map!(Router, Set!(Matcher.MatchType)) routerMatchTypes = new HashMap!(Router, Set!(Matcher.MatchType))();
        Map!(Router, Map!(string, string)) routerParameters = new HashMap!(Router, Map!(string, string))();

        findRouter(method, Matcher.MatchType.METHOD, routerMatchTypes, routerParameters);
        findRouter(path, Matcher.MatchType.PATH, routerMatchTypes, routerParameters);
        // findRouter(contentType, Matcher.MatchType.CONTENT_TYPE, routerMatchTypes, routerParameters);
        // findRouter(accept, Matcher.MatchType.ACCEPT, routerMatchTypes, routerParameters);

        NavigableSet!(RouterMatchResult) ret = new TreeSet!(RouterMatchResult)();
        foreach(Router key, Set!(Matcher.MatchType) value; routerMatchTypes) {
            if(!key.isEnable()) continue;
            if(key.getMatchTypes() != value) continue;
            RouterMatchResult e = new RouterMatchResult(key, routerParameters.get(key), value);
            ret.add(e);
        }
        return ret;
    }

    private void findRouter(string value, Matcher.MatchType matchType,
                            Map!(Router, Set!(Matcher.MatchType)) routerMatchTypes,
                            Map!(Router, Map!(string, string)) routerParameters) {

        List!(Matcher) matchers = matcherMap.get(matchType);

        // FIXME: Needing refactor or cleanup -@zhangxueping at 2020-03-31T17:33:01+08:00
        // https://forum.dlang.org/post/exknjzbuooofyulgeaen@forum.dlang.org
        for(int i=0; i<matchers.size(); i++) {
            Matcher m = matchers.get(i);
        
        // foreach(Matcher m; matchers) {
            MatchResult mr = m.match(value);
            if(mr is null) continue;

            Set!(Router) routers = mr.getRouters();
            foreach(Router router; routers) {
                routerMatchTypes.computeIfAbsent(router, k => new HashSet!(Matcher.MatchType)())
                                .add(mr.getMatchType());
                Map!(Router, Map!(string, string)) parameters = mr.getParameters();

                if (parameters !is null && !parameters.isEmpty()) {
                    routerParameters.computeIfAbsent(router, k => new HashMap!(string, string)())
                                    .putAll(parameters.get(router));
                }
            }

        }
    }

    override Router register() {
        return new RouterImpl(idGenerator++, this);
    }

    override Router register(int id) {
        return new RouterImpl(id, this);
    }

    override void accept(HttpServerContext context) {
        HttpRequest request = context.httpRequest();
        NavigableSet!(RouterMatchResult) routers = findRouter(
                request.getMethod(),
                request.getURI().getPath(),
                request.getFields().get(HttpHeader.CONTENT_TYPE),
                request.getFields().get(HttpHeader.ACCEPT));
        RoutingContext routingContext = new RoutingContextImpl(context, routers);
        routingContext.next();
    }
}
