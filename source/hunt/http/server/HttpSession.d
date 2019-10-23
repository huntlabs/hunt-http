module hunt.http.server.HttpSession;

import hunt.http.Exceptions;

import hunt.collection.HashMap;
import hunt.collection.Map;
import hunt.Exceptions;
import hunt.util.DateTime;
import hunt.util.Lifecycle;

import std.variant;


/**
 * 
 */
class HttpSession  { // : Serializable

    private string id;
    private long creationTime;
    private long lastAccessedTime;
    private int maxInactiveInterval;
    private Variant[string] attributes;
    private bool newSession;

    string getId() {
        return id;
    }

    void setId(string id) {
        this.id = id;
    }

    long getCreationTime() {
        return creationTime;
    }

    void setCreationTime(long creationTime) {
        this.creationTime = creationTime;
    }

    long getLastAccessedTime() {
        return lastAccessedTime;
    }

    void setLastAccessedTime(long lastAccessedTime) {
        this.lastAccessedTime = lastAccessedTime;
    }

    /**
     * Get the max inactive interval. The time unit is second.
     *
     * @return The max inactive interval.
     */
    int getMaxInactiveInterval() {
        return maxInactiveInterval;
    }

    /**
     * Set the max inactive interval. The time unit is second.
     *
     * @param maxInactiveInterval The max inactive interval.
     */
    void setMaxInactiveInterval(int maxInactiveInterval) {
        this.maxInactiveInterval = maxInactiveInterval;
    }

    Variant[string] getAttributes() {
        return attributes;
    }

    void setAttribute(T)(string key, T value) if(!is(T == Variant)) {
        setAttribute(key, value.Variant);
    }

    void setAttribute(string key, Variant value) {
        attributes[key] = value;
    }

    Variant getAttribute(string key) {
        return attributes.get(key, Variant(null));
    }

    T getAttributeAs(T)(string key) {
        if(hasAttribute(key))
            return attributes[key].get!(T);
        else
            return T.init;
    }

    bool hasAttribute(string key) {
        auto itemPtr = key in attributes;
        return itemPtr !is null;
    }

    bool isNewSession() {
        return newSession;
    }

    void setNewSession(bool newSession) {
        this.newSession = newSession;
    }

    bool isInvalid() {
        long currentTime = DateTime.currentTimeMillis(); 
        return (currentTime - lastAccessedTime) > (maxInactiveInterval * 1000);
    }

    static HttpSession create(string id, int maxInactiveInterval) {
        long currentTime = DateTime.currentTimeMillis();
        HttpSession session = new HttpSession();
        session.setId(id);
        session.setMaxInactiveInterval(maxInactiveInterval);
        session.setCreationTime(currentTime);
        session.setLastAccessedTime(session.getCreationTime());
        // session.setAttributes(new HashMap!(string, Object)());
        session.setNewSession(true);
        return session;
    }

    override
    bool opEquals(Object o) {
        if (this is o) return true;
        if (o is null || typeid(this) != typeid(o)) return false;
        HttpSession that = cast(HttpSession) o;
        return id == that.id;
    }

    override
    size_t toHash() @trusted nothrow {
        return hashOf(id);
    }
}



/**
 * 
 */
interface SessionStore : Lifecycle {

    bool contains(string key);

    bool remove(string key);

    bool put(string key, HttpSession value);

    HttpSession get(string key);

    int size();

}


/**
 * 
 */
interface HttpSessionHandler {

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



// /**
//  * 
//  */
// class HttpSessionConfiguration {

//     private string sessionIdParameterName = "hunt-sessionid";
//     private int defaultMaxInactiveInterval = 10 * 60; //second

//     string getSessionIdParameterName() {
//         return sessionIdParameterName;
//     }

//     void setSessionIdParameterName(string sessionIdParameterName) {
//         this.sessionIdParameterName = sessionIdParameterName;
//     }

//     int getDefaultMaxInactiveInterval() {
//         return defaultMaxInactiveInterval;
//     }

//     void setDefaultMaxInactiveInterval(int defaultMaxInactiveInterval) {
//         this.defaultMaxInactiveInterval = defaultMaxInactiveInterval;
//     }
// }