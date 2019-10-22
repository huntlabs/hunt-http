module hunt.http.routing.impl.PatternPathMatcher;


import hunt.http.routing.impl.AbstractPatternMatcher;
import hunt.http.routing.Matcher;

alias MatchType = Matcher.MatchType;
alias MatchResult = Matcher.MatchResult;


/**
 * 
 */
class PatternPathMatcher : AbstractPatternMatcher {

    override
    MatchType getMatchType() {
        return MatchType.PATH;
    }

}
