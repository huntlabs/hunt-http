module hunt.http.routing.impl.PrecisePathMatcher;

import hunt.http.routing.impl.AbstractPreciseMatcher;

import hunt.http.routing.Matcher;
import hunt.text;
import std.range;

alias MatchType = Matcher.MatchType;
alias MatchResult = Matcher.MatchResult;

/**
 * 
 */
class PrecisePathMatcher : AbstractPreciseMatcher {


    override
    MatchResult match(string value) {
        if (value.empty() || value[$-1] != '/') {
            value ~= "/";
        }

        return super.match(value);
    }

    override
    MatchType getMatchType() {
        return MatchType.PATH;
    }
}
