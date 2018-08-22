module hunt.http.server.http.router.Router;

import hunt.http.server.http.router.handler;
import hunt.http.server.http.router.Matcher;

import hunt.http.codec.http.model.HttpMethod;

import hunt.container.List;
import hunt.container.Set;

import hunt.util.common;


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

    Router handler(Handler handler);

    // Router handler(RoutingHandler handler);

    Router enable();

    Router disable();

    // int opCmp(Router o);
}
