module hunt.http.router.impl.PatternPathMatcher;


import hunt.http.router.impl.AbstractPatternMatcher;
import hunt.http.router.Matcher;

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
