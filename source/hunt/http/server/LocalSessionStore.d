module hunt.http.server.LocalSessionStore;

import hunt.http.Exceptions;
import hunt.http.server.HttpSession;

import hunt.collection.HashMap;
import hunt.logging.ConsoleLogger;
import hunt.util.DateTime;
import hunt.util.Lifecycle;

import core.sync.mutex;
import std.range;


/**
 * 
 */
class LocalSessionStore : AbstractLifecycle, SessionStore {

    private HashMap!(string, HttpSession) map;
    private Mutex mapMutex;
    
    // private final ConcurrentMap<string, HttpSession map = new ConcurrentHashMap<>();
    // private final Scheduler scheduler = Schedulers.createScheduler();

    this() {
        map = new HashMap!(string, HttpSession);
        mapMutex = new Mutex();
        start();
    }


    bool contains(string key) {
        return map.containsKey(key);
    }


    override
    bool remove(string key) {
        if (!key.empty()) {
            mapMutex.lock();
            scope(exit) mapMutex.unlock();
        
            map.remove(key);
        }
        return true;
    }

    override
    bool put(string key, HttpSession value) {
        if (!key.empty() && value !is null) {
            if (!value.isNewSession()) {
                value.setLastAccessedTime(DateTime.currentTimeMillis());
            }
            mapMutex.lock();
            scope(exit) mapMutex.unlock();
            map.put(key, value);
        }
        return true;
    }

    override
    HttpSession get(string key) {
        if (key.empty()) {
            throw new SessionNotFoundException();
        }

        mapMutex.lock();
        scope(exit) mapMutex.unlock();
        HttpSession session = map.get(key);
        if (session is null) {
            throw new SessionNotFoundException(key);
        } else {
            if (session.isInvalid()) {
                map.remove(session.getId());
                throw new SessionInvalidException("the session is expired");
            } else {
                session.setLastAccessedTime(DateTime.currentTimeMillis());
                session.setNewSession(false);
                return session;
            }
        }
    }

    override
    int size() {
        return map.size();
    }

    override
    protected void initialize() {
        // TODO: Tasks pending completion -@zhangxueping at 2019-10-22T10:19:19+08:00
        // 
        // scheduler.scheduleWithFixedDelay(() - map.forEach((id, session) - {
        //     if (session.isInvalid()) {
        //         map.remove(id);
        //         tracef("remove expired local HTTP session - %d", id);
        //     }
        // }), 1, 1, TimeUnit.SECONDS);
    }

    override
    protected void destroy() {
        // scheduler.stop();
    }
}    