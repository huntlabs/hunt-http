module hunt.http.server.http.router.impl.RegexPathMatcher;



import hunt.http.server.http.router.impl.AbstractRegexMatcher;
import hunt.http.server.http.router.Matcher;

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
