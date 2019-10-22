module hunt.http.routing.impl.RegexPathMatcher;



import hunt.http.routing.impl.AbstractRegexMatcher;
import hunt.http.routing.Matcher;

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
