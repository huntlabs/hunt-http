module hunt.http.server.http.router.impl.AcceptHeaderMatcher;

import hunt.http.server.http.router.impl.AbstractPreciseMatcher;
import hunt.http.server.http.router.Matcher;
import hunt.http.server.http.router.Router;

import hunt.http.codec.http.model.AcceptMIMEType;

import hunt.util.string;
import hunt.util.exception;
import hunt.container;

import hunt.http.codec.http.model.MimeTypes; //.parseAcceptMIMETypes;

alias MatchType = Matcher.MatchType;
alias MatchResult = Matcher.MatchResult;

import std.algorithm;
import std.container.array;
import std.string; 

import kiss.logger;

/**
 * 
 */
class AcceptHeaderMatcher : AbstractPreciseMatcher {

    override MatchType getMatchType() {
        return MatchType.ACCEPT;
    }

    private bool checkKey(AcceptMIMEType type, string key) {
        string[] t = StringUtils.split(key, "/");
        string p = t[0].strip();
        string c = t[1].strip();
        switch (type.getMatchType()) {
            case AcceptMIMEMatchType.EXACT:
                return p.equals(type.getParentType()) && c.equals(type.getChildType());
            case AcceptMIMEMatchType.CHILD:
                return c.equals(type.getChildType());
            case AcceptMIMEMatchType.PARENT:
                return p.equals(type.getParentType());
            case AcceptMIMEMatchType.ALL:
                return true;
            default:
                return false;
        }
    }

    override MatchResult match(string value) {
        if (_map is null) {
            return null;
        }

        Array!AcceptMIMEType acceptMIMETypes = MimeTypes.parseAcceptMIMETypes(value);
        Set!Router set = new HashSet!Router();

        foreach (AcceptMIMEType type ; acceptMIMETypes) {
            foreach(string key, Set!(Router) value; _map) {
                if(checkKey(type, key)) {
                    set.addAll(value);
                }
            }

            if(!set.isEmpty())
                return new MatchResult(set, Collections.emptyMap!(Router, Map!(string, string))(), getMatchType());
        }

        return null;
    }
}
