module hunt.http.router.Router;

import hunt.http.router.Matcher;
import hunt.http.router.RoutingContext;
import hunt.http.router.RoutingHandler;

import hunt.http.codec.http.model.HttpMethod;

import hunt.collection.List;
import hunt.collection.Set;

import hunt.util.Common;


/**
 * 
 */
interface Router : Comparable!Router {

    int getId();

    bool isEnable();

    Set!(Matcher.MatchType) getMatchTypes();

    Router path(string url);

    Router paths(string[] urlList);

    Router pathRegex(string regex);

    Router method(string method);

    Router method(HttpMethod httpMethod);

    Router get(string url);

    Router post(string url);

    Router put(string url);

    Router del(string url);

    Router consumes(string contentType);

    Router produces(string accept);

    Router handler(IRoutingHandler handler);

    Router handler(RoutingHandler handler);

    void handle(RoutingContext context);

    Router enable();

    Router disable();

    // int opCmp(Router o);
}
