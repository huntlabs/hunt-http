module hunt.http.server.http.router.impl.AbstractRegexMatcher;

import hunt.http.server.http.router.Matcher;
import hunt.http.server.http.router.Router;

import hunt.container;

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
            pattern = regex(rule); // Pattern.compile(rule);
        }

        override
        bool opEquals(Object o) {
            if (this is o) return true;
            if (o is null || typeid(this) !is typeid(o)) return false;
            RegexRule regexRule = cast(RegexRule) o;
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

        // regexMap.forEach((rule, routerSet) 
        foreach(rule, routerSet; _regexMap)
        {
            RegexMatch!string m = matchAll(value, rule.pattern);

            if (m.empty) 
                continue;

            routers.addAll(routerSet);
            // m = rule.pattern.matcher(value);
            // FIXME: Needing refactor or cleanup -@zxp at 7/24/2018, 6:32:00 PM
            // 

            Map!(string, string) param = new HashMap!(string, string)();
            int i=0;
            foreach(Captures!string item; m)
            {
                param.put("group" ~ i.to!string(), item.front);
                i++;
            }
            // while (m.find()) {
            //     for (int i = 1; i <= m.groupCount(); i++) {
            //         param.put("group" ~ i.to!string(), m.group(i));
            //     }
            // }
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


    MatchType getMatchType();
}
