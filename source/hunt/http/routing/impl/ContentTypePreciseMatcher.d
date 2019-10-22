module hunt.http.routing.impl.ContentTypePreciseMatcher;

import hunt.http.routing.impl.AbstractPreciseMatcher;
import hunt.util.MimeTypeUtils;
import hunt.text;


import hunt.http.routing.Matcher;
import std.range;

alias MatchType = Matcher.MatchType;
alias MatchResult = Matcher.MatchResult;

/**
 * 
 */
class ContentTypePreciseMatcher : AbstractPreciseMatcher {

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
