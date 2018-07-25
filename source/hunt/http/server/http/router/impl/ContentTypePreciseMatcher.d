module hunt.http.server.http.router.impl.ContentTypePreciseMatcher;

import hunt.http.server.http.router.impl.AbstractPreciseMatcher;
import hunt.http.codec.http.model.MimeTypes;
import hunt.util.string;

import hunt.http.server.http.router.Matcher;
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
        string mimeType = MimeTypes.getContentTypeMIMEType(value);
        if (!mimeType.empty()) {
            return super.match(mimeType);
        } else {
            return null;
        }
    }
}
