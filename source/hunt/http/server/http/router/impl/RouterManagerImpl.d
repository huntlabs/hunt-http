module hunt.http.server.http.router.impl.RouterManagerImpl;

import hunt.http.server.http.router.impl.ContentTypePreciseMatcher;
import hunt.http.server.http.router.impl.ContentTypePatternMatcher;
import hunt.http.server.http.router.impl.AcceptHeaderMatcher;
import hunt.http.server.http.router.impl.HTTPMethodMatcher;
import hunt.http.server.http.router.impl.PatternPathMatcher;
import hunt.http.server.http.router.impl.PrecisePathMatcher;
import hunt.http.server.http.router.impl.ParameterPathMatcher;
import hunt.http.server.http.router.impl.RegexPathMatcher;
import hunt.http.server.http.router.impl.RouterImpl;

import hunt.http.codec.http.model.HttpHeader;
import hunt.http.server.http.SimpleRequest;
import hunt.http.server.http.router.Matcher;
import hunt.http.server.http.router.Router;
import hunt.http.server.http.router.RouterManager;
import hunt.http.server.http.router.RoutingContext;
// import hunt.http.utils.CollectionUtils;

import hunt.container;

import hunt.util.exception;

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
    private Matcher contentTypePreciseMatcher;
    private Matcher contentTypePatternMatcher;
    private Matcher acceptHeaderMatcher;

    this() {
        matcherMap = new HashMap!(Matcher.MatchType, List!(Matcher))();
        precisePathMather = new PrecisePathMatcher();
        patternPathMatcher = new PatternPathMatcher();
        parameterPathMatcher = new ParameterPathMatcher();
        regexPathMatcher = new RegexPathMatcher();
        ArrayList!Matcher al = new ArrayList!Matcher([precisePathMather, patternPathMatcher, parameterPathMatcher, regexPathMatcher]);
        matcherMap.put(Matcher.MatchType.PATH, al);

        httpMethodMatcher = new HTTPMethodMatcher();
        matcherMap.put(Matcher.MatchType.METHOD, Collections.singletonList!(Matcher)(httpMethodMatcher));

        contentTypePreciseMatcher = new ContentTypePreciseMatcher();
        contentTypePatternMatcher = new ContentTypePatternMatcher();
        al = new ArrayList!Matcher([contentTypePreciseMatcher, contentTypePatternMatcher]);
        matcherMap.put(Matcher.MatchType.CONTENT_TYPE, al);

        acceptHeaderMatcher = new AcceptHeaderMatcher();
        matcherMap.put(Matcher.MatchType.ACCEPT, Collections.singletonList!(Matcher)(acceptHeaderMatcher));
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

    Matcher getContentTypePreciseMatcher() {
        return contentTypePreciseMatcher;
    }

    Matcher getAcceptHeaderMatcher() {
        return acceptHeaderMatcher;
    }

    Matcher getContentTypePatternMatcher() {
        return contentTypePatternMatcher;
    }

    // override
    // NavigableSet<RouterMatchResult> findRouter(string method, string path, string contentType, string accept) {
    //     Map<Router, Set<Matcher.MatchType>> routerMatchTypes = new HashMap<>();
    //     Map<Router, Map!(string, string)> routerParameters = new HashMap<>();
    //     findRouter(method, Matcher.MatchType.METHOD, routerMatchTypes, routerParameters);
    //     findRouter(path, Matcher.MatchType.PATH, routerMatchTypes, routerParameters);
    //     findRouter(contentType, Matcher.MatchType.CONTENT_TYPE, routerMatchTypes, routerParameters);
    //     findRouter(accept, Matcher.MatchType.ACCEPT, routerMatchTypes, routerParameters);

    //     NavigableSet<RouterMatchResult> ret = new TreeSet<>();
    //     routerMatchTypes.entrySet()
    //                     .stream()
    //                     .filter(e -> e.getKey().isEnable())
    //                     .filter(e -> e.getKey().getMatchTypes().equals(e.getValue()))
    //                     .map(e -> new RouterMatchResult(e.getKey(), routerParameters.get(e.getKey()), e.getValue()))
    //                     .forEach(ret::add);
    //     return ret;
    // }

    // private void findRouter(string value, Matcher.MatchType matchType,
    //                         Map<Router, Set<Matcher.MatchType>> routerMatchTypes,
    //                         Map<Router, Map!(string, string)> routerParameters) {
    //     matcherMap.get(matchType)
    //               .stream()
    //               .map(m -> m.match(value))
    //               .filter(Objects::nonNull)
    //               .forEach(result -> result.getRouters().forEach(router -> {
    //                   routerMatchTypes.computeIfAbsent(router, k -> new HashSet<>())
    //                                   .add(result.getMatchType());
    //                   if (!CollectionUtils.isEmpty(result.getParameters())) {
    //                       routerParameters.computeIfAbsent(router, k -> new HashMap<>())
    //                                       .putAll(result.getParameters().get(router));
    //                   }
    //               }));
    // }

    override
    Router register() {
        return new RouterImpl(idGenerator++, this);
    }

    override
    Router register(int id) {
        return new RouterImpl(id, this);
    }

    override
    void accept(SimpleRequest request) {
        implementationMissing();
        // NavigableSet<RouterMatchResult> routers = findRouter(
        //         request.getMethod(),
        //         request.getURI().getPath(),
        //         request.getFields().get(HttpHeader.CONTENT_TYPE),
        //         request.getFields().get(HttpHeader.ACCEPT));
        // RoutingContext routingContext = new RoutingContextImpl(request, routers);
        // routingContext.next();
    }
}
