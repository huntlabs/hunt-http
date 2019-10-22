module hunt.http.routing.impl.AbstractPatternMatcher;

import hunt.http.routing.Matcher;
import hunt.http.routing.Router;

import hunt.Exceptions;
import hunt.collection;

import hunt.logging;
import hunt.text;

import std.conv;
import std.regex;
import std.array;

/**
 * 
 */
abstract class AbstractPatternMatcher : Matcher {

    protected Map!(PatternRule, Set!(Router)) _patternMap;

    protected static class PatternRule {
        string rule;
        Pattern pattern;

        protected this(string rule) {
            this.rule = rule;
            string[] rules = rule.split("*").array;
            pattern = Pattern.compile(rule, "*");
        }

        override
        bool opEquals(Object o) {
            if (this is o) return true;
            PatternRule that = cast(PatternRule) o;
            if(that is null)   return false;
            return rule == that.rule;
        }

        override
        size_t toHash() @trusted nothrow {
            return hashOf(rule);
        }
    }

    this()
    {
        _patternMap = new HashMap!(PatternRule, Set!(Router))();
    }

    // protected Map!(PatternRule, Set!(Router)) patternMap() {
    //     if (_patternMap is null) {
    //         _patternMap = new HashMap!(PatternRule, Set!(Router))();
    //     }
    //     return _patternMap;
    // }

    abstract MatchType getMatchType() { implementationMissing(); return MatchType.PATH; }

    void add(string rule, Router router) {
        _patternMap.computeIfAbsent(new PatternRule(rule), k => new HashSet!Router()).add(router);
        //trace("_patternMap size: ", _patternMap.size()) ;
    }

    MatchResult match(string v) {
        if (_patternMap is null) {
            return null;
        }

        Set!Router routers = new HashSet!Router();
        Map!(Router, Map!(string, string)) parameters = new HashMap!(Router, Map!(string, string))();

        foreach(PatternRule rule, Set!(Router) routerSet; _patternMap)
        {
            // tracef("v=%s, pattern=%s", v, rule.rule);
            string[] strings = rule.pattern.match(v);
            if (strings.length == 0) 
                continue;

            routers.addAll(routerSet);
            Map!(string, string) param = new HashMap!(string, string)();

            int i=0;
            foreach(string item; strings) {
                // tracef("%d => %s", i, item);
                param.put("param" ~ i.to!string(), item);
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
