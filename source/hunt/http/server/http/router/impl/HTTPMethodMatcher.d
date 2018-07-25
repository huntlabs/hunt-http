module hunt.http.server.http.router.impl.HTTPMethodMatcher;

import hunt.http.server.http.router.impl.AbstractPreciseMatcher;
import hunt.http.server.http.router.Matcher;

import std.string;

alias MatchType = Matcher.MatchType;
alias MatchResult = Matcher.MatchResult;

/**
 * 
 */
class HTTPMethodMatcher : AbstractPreciseMatcher {

    override
    MatchResult match(string value) {
        return super.match(value.toUpper());
    }

    override
    MatchType getMatchType() {
        return MatchType.METHOD;
    }
}
