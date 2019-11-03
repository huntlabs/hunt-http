module hunt.http.Util;

import hunt.concurrency.Executors;
import hunt.concurrency.ExecutorService;
import hunt.concurrency.Scheduler;
import hunt.concurrency.ScheduledThreadPoolExecutor;

import std.concurrency : initOnce;

/**
 * 
 */
struct CommonUtil {
    
    static ScheduledThreadPoolExecutor scheduler() {
        return initOnce!_scheduler(cast(ScheduledThreadPoolExecutor) Executors.newScheduledThreadPool(5));
    }
    private __gshared ScheduledThreadPoolExecutor _scheduler;

    static void stopScheduler() {
        if (_scheduler !is null) {
            _scheduler.shutdown();
        }
    }
}