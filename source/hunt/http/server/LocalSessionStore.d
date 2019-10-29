module hunt.http.server.LocalSessionStore;

import hunt.http.server.HttpSession;
import hunt.http.server.GlobalSettings;

import hunt.http.Exceptions;

import hunt.collection.HashMap;
// import hunt.concurrency.Executors;
// import hunt.concurrency.Scheduler;
import hunt.concurrency.ScheduledThreadPoolExecutor;
import hunt.logging.ConsoleLogger;
import hunt.util.Common;
import hunt.util.DateTime;
import hunt.util.Lifecycle;

import core.sync.mutex;
import core.time;
import std.range;


/**
 * 
 */
class LocalSessionStore : AbstractLifecycle, SessionStore {

    private HashMap!(string, HttpSession) map;
    private Mutex mapMutex;
    private ScheduledThreadPoolExecutor executor;
    // TODO: Tasks pending completion -@zhangxueping at 2019-10-23T11:21:26+08:00
    // 
    // private final ConcurrentMap<string, HttpSession map = new ConcurrentHashMap<>();

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

    private void cleaup() {
        mapMutex.lock();
        scope(exit) mapMutex.unlock();
        string[] ids;
        foreach(string id, HttpSession session; map) {
            if (session.isInvalid()) {
                ids ~= id; 
            }
        }

        if(ids.length>0) {
            foreach(string id; ids) {
                map.remove(id);
                version(HUNT_DEBUG) tracef("remove expired session - %s", id);
            }

            version(HUNT_HTTP_DEBUG) infof("session size: %d", map.size());
        }
    }

    override
    protected void initialize() {
        // executor = cast(ScheduledThreadPoolExecutor) Executors.newScheduledThreadPool(1);
        executor = GlobalSettings.scheduler();
        executor.setRemoveOnCancelPolicy(true);
        executor.scheduleWithFixedDelay(new class Runnable {
            void run() {
                cleaup();
            }
        }, 
        seconds(1), seconds(1));
    }

    override
    protected void destroy() {
        // if (executor !is null) {
        //     executor.shutdown();
        // }
    }
}    