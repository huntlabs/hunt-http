module hunt.http.routing.AbstractHttpSessionHandler;

import hunt.http.routing.RoutingContext;
import hunt.http.server.HttpSession;

import hunt.http.Cookie;
import hunt.logging.ConsoleLogger;

import std.algorithm;
import std.string;
import std.range;

/** 
 * 
 */
abstract class AbstractHttpSessionHandler : HttpSessionHandler {

    protected RoutingContext routingContext;

    protected string sessionIdParameterName = "huntsessionid";
    protected int defaultMaxInactiveInterval = 5 * 60; //second

    protected bool requestedSessionIdFromURL;
    protected bool requestedSessionIdFromCookie;
    protected string requestedSessionId;

    this(RoutingContext routingContext, string sessionIdParameterName, int defaultMaxInactiveInterval) {
        this.routingContext = routingContext;
        if (!sessionIdParameterName.empty()) {
            this.sessionIdParameterName = sessionIdParameterName;
        }
        if (defaultMaxInactiveInterval > 0) {
            this.defaultMaxInactiveInterval = defaultMaxInactiveInterval;
        }
        initialize();
    }

    protected void initialize() {
        if (getHttpSessionFromCookie() is null) {
            getHttpSessionFromURL();
        }
    }

    protected string getHttpSessionFromURL() {
        if (requestedSessionId != null) {
            return requestedSessionId;
        }

        string param = routingContext.getURI().getParam();
        if (param.empty()) {
            string prefix = sessionIdParameterName ~ "=";
            if (param.length > prefix.length) {
                ptrdiff_t s = param.indexOf(prefix);
                if (s >= 0) {
                    s += prefix.length;
                    requestedSessionId = param[s .. $];
                    requestedSessionIdFromCookie = false;
                    requestedSessionIdFromURL = true;
                    return requestedSessionId;
                }
            }
        }
        return null;
    }

    protected string getHttpSessionFromCookie() {
        if (!requestedSessionId.empty()) {
            return requestedSessionId;
        }

        Cookie[] cookies = routingContext.getCookies();
        if (!cookies.empty()) {
            Cookie[] results = cookies.find!(c => icmp(sessionIdParameterName, c.getName()) == 0);
            if(!results.empty) {
                Cookie c = results[0];
                requestedSessionIdFromCookie = true;
                requestedSessionIdFromURL = false;
                requestedSessionId = c.getValue();
                return requestedSessionId;
            }
        }
        return null;
    }

    override
    bool isRequestedSessionIdFromURL() {
        return requestedSessionIdFromURL;
    }

    override
    bool isRequestedSessionIdFromCookie() {
        return requestedSessionIdFromCookie;
    }

    override
    string getRequestedSessionId() {
        return requestedSessionId;
    }

    override
    string getSessionIdParameterName() {
        return sessionIdParameterName;
    }
}
