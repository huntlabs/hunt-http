module hunt.http.router.impl.AbstractRegexMatcher;

import hunt.http.router.Matcher;
import hunt.http.router.Router;

import hunt.collection;
import hunt.Exceptions;

import hunt.logging;

import std.conv;
import std.regex;


/**
 * 
 */
abstract class AbstractRegexMatcher : Matcher {

    protected Map!(RegexRule, Set!Router) _regexMap;

    protected static class RegexRule {
        string rule;
        Regex!char pattern;
        
        protected this(string rule) {
            this.rule = rule;
            pattern = regex(rule);
        }

        override
        bool opEquals(Object o) {
            if (this is o) return true;
            RegexRule regexRule = cast(RegexRule) o;
            if(regexRule is null) return false;
            return rule == regexRule.rule;
        }

        override
        size_t toHash() @trusted nothrow {
            return hashOf(rule);
        }
    }

    protected Map!(RegexRule, Set!(Router)) regexMap() {
        if (_regexMap is null) {
            _regexMap = new HashMap!(RegexRule, Set!(Router))();
        }
        return _regexMap;
    }

    override
    void add(string rule, Router router) {
        // regexMap().computeIfAbsent(new RegexRule(rule), k -> new HashSet<>()).add(router);
        auto r = new RegexRule(rule);
        if(regexMap().containsKey(r))
        {
            regexMap()[r].add(router);
        }
        else
        {
            auto hs = new HashSet!(Router)();
            hs.add(router);
            regexMap().put(r, hs);
        }
    }

    override
    MatchResult match(string value) {
        if (_regexMap is null) {
            return null;
        }

        Set!Router routers = new HashSet!Router();
        Map!(Router, Map!(string, string)) parameters = new HashMap!(Router, Map!(string, string))();

        foreach(RegexRule rule, Set!Router routerSet; _regexMap)
        {
            // tracef("v=%s, pattern=%s", value, rule.rule);
            RegexMatch!string m = matchAll(value, rule.pattern);

            if (m.empty) 
                continue;

            routers.addAll(routerSet);

            Map!(string, string) param = new HashMap!(string, string)();
            foreach(Captures!string item; m)
            {
                // tracef("front:%s, length:%d", item.front, item.length);
                for (size_t i = 1; i <item.length; i++) {
                    // tracef("%d => %s", i, item[i]);
                    param.put("group" ~ i.to!string(), item[i]);
                }                
            }

            if (!param.isEmpty()) {
                foreach(router; routerSet)
                    parameters.put(router, param);
            }
        }
        if (routers.isEmpty()) {
            return null;
        } else {
            return new MatchResult(routers, parameters, getMatchType());
        }
    }


    MatchType getMatchType() { implementationMissing(); return MatchType.PATH; }

}
