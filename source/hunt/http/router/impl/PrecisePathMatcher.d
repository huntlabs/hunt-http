module hunt.http.router.impl.PrecisePathMatcher;

import hunt.http.router.impl.AbstractPreciseMatcher;

import hunt.http.router.Matcher;
import hunt.text;

alias MatchType = Matcher.MatchType;
alias MatchResult = Matcher.MatchResult;

/**
 * 
 */
class PrecisePathMatcher : AbstractPreciseMatcher {


    override
    MatchResult match(string value) {
        if (value[$-1] != '/') {
            value ~= "/";
        }

        return super.match(value);
    }

    override
    MatchType getMatchType() {
        return MatchType.PATH;
    }
}
