module hunt.http.server.GlobalSettings;

import hunt.http.server.HttpServerOptions;

import hunt.concurrency.Executors;
import hunt.concurrency.ExecutorService;
import hunt.concurrency.Scheduler;
import hunt.concurrency.ScheduledThreadPoolExecutor;

import std.concurrency : initOnce;

struct GlobalSettings {

    __gshared HttpServerOptions httpServerOptions;

    static ScheduledThreadPoolExecutor scheduler() {
        return initOnce!_scheduler(cast(ScheduledThreadPoolExecutor) Executors.newScheduledThreadPool(10));
    }
    private __gshared ScheduledThreadPoolExecutor _scheduler;

    static void stopScheduler() {
        if (_scheduler !is null) {
            _scheduler.shutdown();
        }
    }

    shared static this() {
        httpServerOptions = new HttpServerOptions();
    }
}
