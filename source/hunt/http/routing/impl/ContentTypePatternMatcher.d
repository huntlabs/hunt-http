module hunt.http.routing.impl.ContentTypePatternMatcher;

import hunt.http.routing.Matcher;

import hunt.http.routing.impl.AbstractPatternMatcher;
import hunt.util.MimeTypeUtils;
import hunt.text;

import std.range;

alias MatchType = Matcher.MatchType;
alias MatchResult = Matcher.MatchResult;

/**
 * 
 */
class ContentTypePatternMatcher : AbstractPatternMatcher {

    override
    MatchType getMatchType() {
        return MatchType.CONTENT_TYPE;
    }

    override
    MatchResult match(string value) {
        string mimeType = MimeTypeUtils.getContentTypeMIMEType(value);
        if (!mimeType.empty()) {
            return super.match(mimeType);
        } else {
            return null;
        }
    }
}
