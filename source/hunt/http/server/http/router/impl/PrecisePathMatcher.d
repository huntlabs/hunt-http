module hunt.http.server.http.router.impl.PrecisePathMatcher;

import hunt.http.server.http.router.impl.AbstractPreciseMatcher;

import hunt.http.server.http.router.Matcher;
import hunt.util.string;

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
