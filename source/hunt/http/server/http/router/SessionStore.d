module hunt.http.server.http.router.SessionStore;

import hunt.http.server.http.router.HttpSession;
import hunt.util.LifeCycle;


/**
 * 
 */
interface SessionStore : LifeCycle {

    bool remove(string key);

    bool put(string key, HttpSession value);

    HttpSession get(string key);

    int size();

}
