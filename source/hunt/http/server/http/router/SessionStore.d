module hunt.http.server.http.router.SessionStore;

import hunt.http.server.http.router.HTTPSession;
import hunt.util.LifeCycle;


/**
 * 
 */
interface SessionStore : LifeCycle {

    bool remove(string key);

    bool put(string key, HTTPSession value);

    HTTPSession get(string key);

    int size();

}
