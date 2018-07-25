module hunt.http.server.http.router.handler.HTTPSessionHandler;

import hunt.http.server.http.router.HTTPSession;

// import javax.servlet.http.HttpSession;

/**
 * 
 */
interface HTTPSessionHandlerSPI {

    HTTPSession getSessionById(string id);

    HTTPSession getSession();

    HTTPSession getSession(bool create);

    HTTPSession getAndCreateSession(int maxAge);

    int getSessionSize();

    bool removeSession();

    bool removeSessionById(string id);

    bool updateSession(HTTPSession httpSession);

    bool isRequestedSessionIdFromURL();

    bool isRequestedSessionIdFromCookie();

    string getRequestedSessionId();

    string getSessionIdParameterName();
}


/**
 * 
 */
class HTTPSessionConfiguration {

    private string sessionIdParameterName = "huntsessionid";
    private int defaultMaxInactiveInterval = 10 * 60; //second

    string getSessionIdParameterName() {
        return sessionIdParameterName;
    }

    void setSessionIdParameterName(string sessionIdParameterName) {
        this.sessionIdParameterName = sessionIdParameterName;
    }

    int getDefaultMaxInactiveInterval() {
        return defaultMaxInactiveInterval;
    }

    void setDefaultMaxInactiveInterval(int defaultMaxInactiveInterval) {
        this.defaultMaxInactiveInterval = defaultMaxInactiveInterval;
    }
}