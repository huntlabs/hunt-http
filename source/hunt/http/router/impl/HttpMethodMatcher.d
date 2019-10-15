module hunt.http.router.impl.HttpMethodMatcher;

import hunt.http.router.impl.AbstractPreciseMatcher;
import hunt.http.router.Matcher;

import std.string;

alias MatchType = Matcher.MatchType;
alias MatchResult = Matcher.MatchResult;

/**
 * 
 */
class HttpMethodMatcher : AbstractPreciseMatcher {

    override
    MatchResult match(string value) {
        return super.match(value.toUpper());
    }

    override
    MatchType getMatchType() {
        return MatchType.METHOD;
    }
}
