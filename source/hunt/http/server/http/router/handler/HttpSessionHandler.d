module hunt.http.server.http.router.handler.HttpSessionHandler;

import hunt.http.server.http.router.HttpSession;

// import javax.servlet.http.HttpSession;

/**
 * 
 */
interface HttpSessionHandlerSPI {

    HttpSession getSessionById(string id);

    HttpSession getSession();

    HttpSession getSession(bool create);

    HttpSession getAndCreateSession(int maxAge);

    int getSessionSize();

    bool removeSession();

    bool removeSessionById(string id);

    bool updateSession(HttpSession httpSession);

    bool isRequestedSessionIdFromURL();

    bool isRequestedSessionIdFromCookie();

    string getRequestedSessionId();

    string getSessionIdParameterName();
}


/**
 * 
 */
class HttpSessionConfiguration {

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