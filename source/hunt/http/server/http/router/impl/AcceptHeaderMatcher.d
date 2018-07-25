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

/**
 * 
 */
class AcceptHeaderMatcher : AbstractPreciseMatcher {

    override
    MatchType getMatchType() {
        return MatchType.ACCEPT;
    }

    override
    MatchResult match(string value) {
        if (_map is null) {
            return null;
        }

        // List!AcceptMIMEType acceptMIMETypes = MimeTypes.parseAcceptMIMETypes(value);
        // if (CollectionUtils.isEmpty(acceptMIMETypes)) {
        //     return null;
        // }
        
        // foreach (AcceptMIMEType type ; acceptMIMETypes) {
        //     Set!Router set = map.entrySet().parallelStream().filter( (e)  {
        //         string[] t = StringUtils.split(e.getKey(), '/');
        //         string p = t[0].strip();
        //         string c = t[1].strip();
        //         switch (type.getMatchType()) {
        //             case EXACT:
        //                 return p.equals(type.getParentType()) && c.equals(type.getChildType());
        //             case CHILD:
        //                 return c.equals(type.getChildType());
        //             case PARENT:
        //                 return p.equals(type.getParentType());
        //             case ALL:
        //                 return true;
        //             default:
        //                 return false;
        //         }
        //     }).map(Map.Entry::getValue).flatMap(Collection::stream).collect(Collectors.toSet());

        //     if (!CollectionUtils.isEmpty(set)) {
        //         return new MatchResult(set, Collections.emptyMap(), getMatchType());
        //     }
        // }

        implementationMissing();

        return null;
    }
}
