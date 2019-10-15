module hunt.http.router.impl.AbstractPreciseMatcher;

import hunt.http.router.Matcher;
import hunt.http.router.Router;

import hunt.collection;
import hunt.Exceptions;

/**
 * 
 */
abstract class AbstractPreciseMatcher : Matcher {

    protected Map!(string, Set!(Router)) _map;

    private Map!(string, Set!(Router)) map() {
        if (_map is null) {
            _map = new HashMap!(string, Set!(Router))();
        }
        return _map;
    }

    override
    void add(string rule, Router router) {
        // map().computeIfAbsent(rule, (k) { new HashSet!()();}).add(router);
        if(map().containsKey(rule))
        {
            map()[rule].add(router);
        }
        else
        {
            auto hs = new HashSet!(Router)();
            hs.add(router);
            map().put(rule, hs);
        }
    }

    override
    MatchResult match(string value) {
        if (map is null) {
            return null;
        }

        Set!(Router) routers = map.get(value);
        if (routers !is null && !routers.isEmpty()) {
            return new MatchResult(routers, Collections.emptyMap!(Router, Map!(string, string))(), getMatchType());
        } else {
            return null;
        }
    }

    MatchType getMatchType() { implementationMissing(); return MatchType.PATH; }

}
