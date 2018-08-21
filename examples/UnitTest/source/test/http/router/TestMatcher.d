module test.http.router.TestMatcher;

import hunt.http.server.http.router.Matcher;
import hunt.http.server.http.router.Router;
import hunt.http.server.http.router.RouterManager;
import hunt.http.server.http.router.impl.RouterManagerImpl;

import hunt.container.NavigableSet;
import hunt.util.Assert;
import hunt.util.exception;

import kiss.logger;


/**
 * 
 */
class TestMatcher {

    void xxtestFindRouter() {
        RouterManager routerManager = new RouterManagerImpl();
        Router router0 = routerManager.register().get("/hello/get").produces("application/json");
        Router router1 = routerManager.register().get("/hello/:testParam0").produces("application/json");
        Router router2 = routerManager.register().get("/hello/:testParam1").produces("application/json");
        Router router3 = routerManager.register().post("/book/update/:id").consumes("*/json");
        Router router4 = routerManager.register().post("/book/update/:id").consumes("application/json");

        NavigableSet!(RouterMatchResult) result = routerManager.findRouter("GET", "/hello/get", null,
                "application/json,text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8");
        assert(result !is null);
        Assert.assertThat(result.size(), (3));
        Assert.assertThat(result.first().getRouter(), (router0));
        Assert.assertThat(result.lower(result.last()).getRouter(), (router1));
        Assert.assertThat(result.last().getRouter(), (router2));
        Assert.assertThat(result.last().getParameters().get("testParam1"), ("get"));

        result = routerManager.findRouter("GET", "/hello/get", null, "application/*,*/*;q=0.8");
        assert(result !is null);
        Assert.assertThat(result.size(), (3));
        Assert.assertThat(result.first().getRouter(), (router0));
        Assert.assertThat(result.lower(result.last()).getRouter(), (router1));
        Assert.assertThat(result.last().getRouter(), (router2));
        Assert.assertThat(result.last().getParameters().get("testParam1"), ("get"));

        result = routerManager.findRouter("GET", "/hello/get", null, "*/json,*/*;q=0.8");
        assert(result !is null);
        Assert.assertThat(result.size(), (3));
        Assert.assertThat(result.first().getRouter(), (router0));
        Assert.assertThat(result.lower(result.last()).getRouter(), (router1));
        Assert.assertThat(result.last().getRouter(), (router2));
        Assert.assertThat(result.last().getParameters().get("testParam1"), ("get"));

        result = routerManager.findRouter("GET", "/hello/get", null, "*/*");
        Assert.assertThat(result.size(), (3));

        result = routerManager.findRouter("GET", "/hello/get", null, null);
        assert(result is null || result.isEmpty());

        result = routerManager.findRouter("POST", "/book/update/3", null, null);
        assert(result is null || result.isEmpty());

        result = routerManager.findRouter("POST", "/book/update/3", "application/json;charset=UTF-8", null);
        assert(result !is null);
        Assert.assertThat(result.size(), (2));
        Assert.assertThat(result.first().getRouter(), (router3));
        Assert.assertThat(result.last().getRouter(), (router4));
        Assert.assertThat(result.last().getParameters().get("id"), ("3"));
        Assert.assertThat(result.first().getParameters().get("param0"), ("application"));
    }

    
    void testProduces() {
        RouterManager routerManager = new RouterManagerImpl();
        Router router0 = routerManager.register().get("/hello/get").produces("application/json");
        Router router1 = routerManager.register().get("/hello/:testParam0").produces("text/html");
        NavigableSet!(RouterMatchResult) result = routerManager.findRouter("GET", "/hello/get", null,
                "text/html,application/xml;q=0.9,application/json;q=0.8");
        Assert.assertThat(result.size(), (1));
        Assert.assertThat(result.first().getRouter(), (router1));

        result = routerManager.findRouter("GET", "/hello/get", null,
                "text/html;q=0.6,application/xml;q=0.7,application/json;q=0.8");
        Assert.assertThat(result.size(), (1));
        Assert.assertThat(result.first().getRouter(), (router0));

        result = routerManager.findRouter("GET", "/hello/get", null,
                "text/html,application/xml,application/json");
        Assert.assertThat(result.size(), (1));
        Assert.assertThat(result.first().getRouter(), (router1));
    }

    
    void testMIMETypeMatcher() {
        RouterManagerImpl routerManager = new RouterManagerImpl();

        Router router0 = routerManager.register().consumes("text/html");
        Router router1 = routerManager.register().consumes("*/json");

        Matcher.MatchResult result = routerManager.getContentTypePreciseMatcher().match("text/html");
        assert(result !is null);
        Assert.assertThat(result.getRouters().size(), (1));
        assert(result.getRouters().contains(router0));

        result = routerManager.getContentTypePatternMatcher().match("application/json");
        assert(result !is null);
        Assert.assertThat(result.getRouters().size(), (1));
        assert(result.getRouters().contains(router1));
        Assert.assertThat(result.getParameters().get(router1).get("param0"), ("application"));
    }

    
    void testMethodMatcher() {
        RouterManagerImpl routerManager = new RouterManagerImpl();

        Router router0 = routerManager.register().post("/food/update");

        Matcher.MatchResult result = routerManager.getHttpMethodMatcher().match("POST");
        assert(result !is null);
        Assert.assertThat(result.getRouters().size(), (1));
        Assert.assertThat(result.getRouters().contains(router0), (true));

        result = routerManager.getPrecisePathMather().match("/food/update");
        assert(result !is null);
        Assert.assertThat(result.getRouters().size(), (1));
        Assert.assertThat(result.getRouters().contains(router0), (true));

        result = routerManager.getHttpMethodMatcher().match("GET");
        assert(result is null);
    }

    void testPathMatcher() {
        RouterManagerImpl routerManager = new RouterManagerImpl();

        Router router0 = routerManager.register().path("/hello/foo");
        Router router1 = routerManager.register().path("/");
        Router router2 = routerManager.register().path("/hello*");
        Router router3 = routerManager.register().path("*");
        Router router4 = routerManager.register().path("/*");
        Router router5 = routerManager.register().path("/he*/*");
        Router router6 = routerManager.register().path("/hello/:foo");
        Router router7 = routerManager.register().path("/:hello/:foo/");
        Router router8 = routerManager.register().path("/hello/:foo/:bar");
        Router router9 = routerManager.register().pathRegex("/hello(\\d*)");

        Matcher.MatchResult result = routerManager.getPrecisePathMather().match("/hello/foo");
        assert(result !is null);
        Assert.assertThat(result.getRouters().size(), (1));
        Assert.assertThat(result.getRouters().contains(router0), (true));

        result = routerManager.getPrecisePathMather().match("/");
        assert(result !is null);
        Assert.assertThat(result.getRouters().size(), (1));
        Assert.assertThat(result.getRouters().contains(router1), (true));

        result = routerManager.getPatternPathMatcher().match("/hello/foo");
        assert(result !is null);
        Assert.assertThat(result.getRouters().size(), (4));
        Assert.assertThat(result.getRouters().contains(router2), (true));
        Assert.assertThat(result.getParameters().get(router2).get("param0"), ("/foo"));
        Assert.assertThat(result.getRouters().contains(router3), (true));
        Assert.assertThat(result.getParameters().get(router3).get("param0"), ("/hello/foo"));
        Assert.assertThat(result.getRouters().contains(router4), (true));
        Assert.assertThat(result.getParameters().get(router4).get("param0"), ("hello/foo"));
        Assert.assertThat(result.getRouters().contains(router5), (true));
        Assert.assertThat(result.getParameters().get(router5).get("param0"), ("llo"));
        Assert.assertThat(result.getParameters().get(router5).get("param1"), ("foo"));

        result = routerManager.getParameterPathMatcher().match("/hello/foooo");
        assert(result !is null);
        Assert.assertThat(result.getRouters().size(), (2));
        Assert.assertThat(result.getRouters().contains(router6), (true));
        Assert.assertThat(result.getRouters().contains(router7), (true));
        Assert.assertThat(result.getParameters().get(router6).get("foo"), ("foooo"));
        Assert.assertThat(result.getParameters().get(router7).get("foo"), ("foooo"));
        Assert.assertThat(result.getParameters().get(router7).get("hello"), ("hello"));

        result = routerManager.getParameterPathMatcher().match("/");
        assert(result is null);

        result = routerManager.getParameterPathMatcher().match("/hello/11/2333");
        assert(result !is null);
        Assert.assertThat(result.getRouters().size(), (1));
        Assert.assertThat(result.getRouters().contains(router8), (true));

        result = routerManager.getRegexPathMatcher().match("/hello113");
        assert(result !is null);
        Assert.assertThat(result.getRouters().size(), (1));
        Assert.assertThat(result.getRouters().contains(router9), (true));
        string r = result.getParameters().get(router9).get("group1");
        Assert.assertThat(r, ("113"));
    }

    
    void testPathMatcher2() {
        RouterManagerImpl routerManager = new RouterManagerImpl();
        Router router0 = routerManager.register().path("/test/*");

        Matcher.MatchResult result = routerManager.getPatternPathMatcher().match("/test/x");
        assert(result !is null);
        Assert.assertThat(result.getRouters().size(), (1));
        Assert.assertThat(result.getRouters().contains(router0), (true));

        Router router1 = routerManager.register().path("/*create*");
        result = routerManager.getPatternPathMatcher().match("/fruit/apple/create");
        assert(result !is null);
        Assert.assertThat(result.getRouters().size(), (1));
        Assert.assertThat(result.getRouters().contains(router1), (true));
        Assert.assertThat(result.getParameters().get(router1).get("param0"), ("fruit/apple/"));
        Assert.assertThat(result.getParameters().get(router1).get("param1"), (""));
    }
}
