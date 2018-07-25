module hunt.http.server.http.router.impl.ParameterPathMatcher;

import hunt.http.server.http.router.Matcher;
import hunt.http.server.http.router.Router;

import hunt.container;

import hunt.util.exception;
import hunt.util.string;

import std.array;
import std.path;
import std.string;

/**
 * 
 */
class ParameterPathMatcher : Matcher {

    private Map!(int, Map!(ParameterPath, Set!(Router))) _parameterPath;

    private static class ParameterPath {
        string rule;
        string[] paths;

        this(string rule) {
            this.rule = rule;
            paths = pathSplitter(rule).array;
        }

        override
        bool opEquals(Object o) {
            if (this == o) return true;
            if (o is null || typeid(this) !is typeid(o)) return false;
            ParameterPath that = cast(ParameterPath) o;
            return rule == that.rule;
        }

        override
        size_t toHash() @trusted nothrow {
            return hashOf(rule);
        }

        Map!(string, string) match(string[] list) {
            Map!(string, string) param = new HashMap!(string, string)();
            for (size_t i = 0; i < list.length; i++) {
                string path = paths[i];
                string value = list[i];

                if (path.charAt(0) != ':') {
                    if (!path.equals(value)) {
                        return null;
                    }
                } else {
                    param.put(path.substring(1), value);
                }
            }
            return param;
        }
    }

    private Map!(int, Map!(ParameterPath, Set!(Router))) parameterPath() {
        if (_parameterPath is null) {
            _parameterPath = new HashMap!(int, Map!(ParameterPath, Set!(Router)))();
        }
        return _parameterPath;
    }

    override
    void add(string rule, Router router) {
        ParameterPath parameterPath = new ParameterPath(rule);
        // parameterPath().computeIfAbsent(parameterPath.paths.size(), k -> new HashMap<>())
        //                .computeIfAbsent(parameterPath, k -> new HashSet<>())
        //                .add(router);
        implementationMissing();
    }

    override
    MatchResult match(string value) {
        if (_parameterPath is null) {
            return null;
        }

        if (value.length == 1) {
            if (value.charAt(0) == '/') {
                return null;
            } else {
                throw new IllegalArgumentException("the path: [" ~ value ~ "] format error");
            }
        } else {
            string[] list = pathSplitter(value).array;
            Map!(ParameterPath, Set!(Router)) map = _parameterPath.get(cast(int)list.length);
            if (map !is null && !map.isEmpty()) {
                Set!(Router) routers = new HashSet!(Router)();
                Map!(Router, Map!(string, string)) parameters = new HashMap!(Router, Map!(string, string))();

                foreach(key, regRouter; map)
                {
                    Map!(string, string) param = key.match(list);
                    if (param !is null) {
                        routers.addAll(regRouter);
                        // regRouter.forEach(router -> parameters.put(router, param));
                        foreach(router; regRouter)
                            parameters.put(router, param);
                    }
                }

                if (!routers.isEmpty()) {
                    return new MatchResult(routers, parameters, getMatchType());
                } else {
                    return null;
                }
            } else {
                return null;
            }
        }
    }

    override
    MatchType getMatchType() {
        return MatchType.PATH;
    }
}
