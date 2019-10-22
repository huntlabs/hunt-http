module hunt.http.routing.Matcher;

import hunt.http.routing.Router;

import hunt.collection.Map;
import hunt.collection.Set;

/**
 * 
 */
interface Matcher {

    enum MatchType {
        PATH, METHOD, ACCEPT, CONTENT_TYPE
    }

    class MatchResult {
        private Set!(Router) routers;
        private Map!(Router, Map!(string, string)) parameters;
        private MatchType matchType;

        this(Set!(Router) routers, Map!(Router, Map!(string, string)) parameters, MatchType matchType) {
            this.routers = routers;
            this.parameters = parameters;
            this.matchType = matchType;
        }

        Set!(Router) getRouters() {
            return routers;
        }

        Map!(Router, Map!(string, string)) getParameters() {
            return parameters;
        }

        MatchType getMatchType() {
            return matchType;
        }
    }

    void add(string rule, Router router);

    MatchResult match(string value);

    MatchType getMatchType();
}
