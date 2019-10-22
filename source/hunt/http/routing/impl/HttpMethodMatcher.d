module hunt.http.routing.impl.HttpMethodMatcher;

import hunt.http.routing.impl.AbstractPreciseMatcher;
import hunt.http.routing.Matcher;

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
