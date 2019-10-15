module hunt.http.router.impl.RegexPathMatcher;



import hunt.http.router.impl.AbstractRegexMatcher;
import hunt.http.router.Matcher;

alias MatchType = Matcher.MatchType;

/**
 * 
 */
class RegexPathMatcher : AbstractRegexMatcher {
    
    override
    MatchType getMatchType() {
        return MatchType.PATH;
    }

}
