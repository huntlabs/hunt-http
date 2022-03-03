module hunt.http.routing.impl.HttpSessionHandlerImpl;

import hunt.http.routing.AbstractHttpSessionHandler;
import hunt.http.routing.RoutingContext;
import hunt.http.server.HttpSession;

import hunt.http.Cookie;
import hunt.http.Exceptions;

import hunt.logging;

import std.algorithm;
import std.string;
import std.range;
import std.uuid;
import std.variant;

/** 
 * 
 */
class HttpSessionHandlerImpl : AbstractHttpSessionHandler {

    private SessionStore sessionStore;
    private string contextSessionKey = "_contextSessionKey";

    this(RoutingContext routingContext, SessionStore sessionStore,
            string sessionIdParameterName, int defaultMaxInactiveInterval) {
        super(routingContext, sessionIdParameterName, defaultMaxInactiveInterval);
        this.sessionStore = sessionStore;
    }

    string getContextSessionKey() {
        return contextSessionKey;
    }

    void setContextSessionKey(string contextSessionKey) {
        this.contextSessionKey = contextSessionKey;
    }

    // override
    HttpSession getSessionById(string id) {
        return sessionStore.get(id);
    }

    // override
    HttpSession getSession() {
        return getSession(true);
    }

    // override
    HttpSession getSession(bool create) {
        return _getSession(create, -1);
    }

    // override
    HttpSession getAndCreateSession(int maxAge) {
        return _getSession(true, maxAge);
    }

    private HttpSession _getSession(bool create, int maxAge) {
        Variant attr = routingContext.getAttribute(contextSessionKey);
        HttpSession currentSession;
        if (attr.type == typeid(HttpSession)) {
            currentSession = attr.get!(HttpSession);
            if(currentSession !is null)
                return currentSession;
        }
        
        try {
            string sid = getSessionId(create);
            version(HUNT_HTTP_DEBUG) infof("SessionId: %s, size: %d", sid, sessionStore.size());
            if(sessionStore.contains(sid)) {
                currentSession = sessionStore.get(sid);
                routingContext.setAttribute(contextSessionKey, currentSession);
            } else {
                currentSession = createSession(maxAge);
            }
        } catch(Exception ex) {
            version(HUNT_DEBUG) warning(ex.msg);
            if(create) {
                SessionInvalidException cause1 = cast(SessionInvalidException)ex;
                SessionNotFoundException cause2 = cast(SessionNotFoundException)ex;
                if(cause1 !is null || cause2 !is null) {
                    currentSession = createSession(maxAge);
                } else {
                    version(HUNT_HTTP_DEBUG) warning(ex);
                }
            } else {
                SessionInvalidException cause = cast(SessionInvalidException)ex;
                if(cause !is null) {
                    removeCookie();
                } else {
                    version(HUNT_HTTP_DEBUG) warning(ex);
                }
            }
        }

        return currentSession;
    }

    private void removeCookie() {
        Cookie cookie = new Cookie(sessionIdParameterName, requestedSessionId);
        cookie.setMaxAge(0);
        routingContext.addCookie(cookie);
    }


    // override
    int getSessionSize() {
        return sessionStore.size();
    }

    // override
    bool removeSession() {
        try {
        sessionStore.remove(requestedSessionId);
        removeCookie();
        routingContext.getAttributes().remove(contextSessionKey);
        } catch(Exception ex) {
            version(HUNT_DEBUG) warning(ex.msg);
            version(HUNT_HTTP_DEBUG) warning(ex);
            return false;
        }
        return true;
    }

    // override
    bool removeSessionById(string id) {
        return sessionStore.remove(id);
    }

    // override
    bool updateSession(HttpSession httpSession) {
        routingContext.setAttribute(contextSessionKey, httpSession);
        return sessionStore.put(requestedSessionId, httpSession);
    }

    protected string getSessionId(bool create) {
        if (create && requestedSessionId.empty()) {
            requestedSessionId = randomUUID().toString().replace("-", "");
        }
        version(HUNT_HTTP_DEBUG_MORE) tracef("create: %s, requestedSessionId: %s", create, requestedSessionId);
        return requestedSessionId;
    }

    protected HttpSession createSession(int maxAge) {
        version(HUNT_HTTP_DEBUG) info("creating new session: ", requestedSessionId);
        HttpSession newSession = HttpSession.create(requestedSessionId, defaultMaxInactiveInterval);
        sessionStore.put(newSession.getId(), newSession);
        createCookie(maxAge);
        routingContext.setAttribute(contextSessionKey, newSession);
        return newSession;
    }

    private void createCookie(int maxAge) {
        Cookie cookie = new Cookie(sessionIdParameterName, requestedSessionId);
        if (maxAge > 0) {
            cookie.setMaxAge(maxAge);
        }
        routingContext.addCookie(cookie);
    }
}
