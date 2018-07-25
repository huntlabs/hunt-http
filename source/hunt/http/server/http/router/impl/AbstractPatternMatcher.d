module hunt.http.server.http.router.impl.AbstractPatternMatcher;


import hunt.http.server.http.router.Matcher;
import hunt.http.server.http.router.Router;
// import hunt.http.utils.pattern.Pattern;

import hunt.util.exception;
import hunt.container;

import std.conv;
import std.regex;

/**
 * 
 */
abstract class AbstractPatternMatcher : Matcher {

    protected Map!(PatternRule, Set!(Router)) _patternMap;

    protected static class PatternRule {
        string rule;
        Regex!char pattern;

        protected this(string rule) {
            this.rule = rule;
            pattern = regex(rule); // Pattern.compile(rule, "*");
        }

        override
        bool opEquals(Object o) {
            if (this is o) return true;
            if (o is null || typeid(this) !is typeid(o)) return false;
            PatternRule that = cast(PatternRule) o;
            return rule == that.rule;
        }

        override
        size_t toHash() @trusted nothrow {
            return hashOf(rule);
        }
    }

    protected Map!(PatternRule, Set!(Router)) patternMap() {
        if (_patternMap is null) {
            _patternMap = new HashMap!(PatternRule, Set!(Router))();
        }
        return _patternMap;
    }

    abstract MatchType getMatchType();

    void add(string rule, Router router) {
        // patternMap().computeIfAbsent(new PatternRule(rule), k => new HashSet<>()).add(router);
        // if(patternMap)
        implementationMissing();
    }

    MatchResult match(string v) {
        if (_patternMap is null) {
            return null;
        }

        Set!Router routers = new HashSet!Router();
        Map!(Router, Map!(string, string)) parameters = new HashMap!(Router, Map!(string, string))();

        // patternMap.forEach((rule, routerSet) 
        foreach(rule, routerSet; patternMap)
        {
            RegexMatch!string strings = matchAll(v, rule.pattern);
            if (strings.empty) 
                continue;

            routers.addAll(routerSet);

            Map!(string, string) param = new HashMap!(string, string)();

            int i=0;
            foreach(Captures!string item; strings) {
                param.put("param" ~ i.to!string(), item.front);
                i++;
            }

            foreach(router; routerSet)
                parameters.put(router, param);

        }
        if (routers.isEmpty()) {
            return null;
        } else {
            return new MatchResult(routers, parameters, getMatchType());
        }
    }

}
