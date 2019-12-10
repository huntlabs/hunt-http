module hunt.http.Util;

import hunt.concurrency.Executors;
import hunt.concurrency.ExecutorService;
import hunt.concurrency.Scheduler;
import hunt.concurrency.ScheduledThreadPoolExecutor;

import std.concurrency : initOnce;

import std.array;
import std.conv;
import std.datetime;
import std.string;

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


    /// convert time to RFC822 format string
    static string toRFC822DateTimeString(SysTime systime) {
        Appender!string ret;

        DateTime dt = cast(DateTime)systime;
        Date date = dt.date;

        ret.put(to!string(date.dayOfWeek).capitalize);
        ret.put(", ");
        ret.put(rightJustify(to!string(date.day), 2, '0'));
        ret.put(" ");
        ret.put(to!string(date.month).capitalize);
        ret.put(" ");
        ret.put(to!string(date.year));
        ret.put(" ");

        TimeOfDay time = cast(TimeOfDay)systime;
        int tz_offset = cast(int)systime.utcOffset.total!"minutes";

        ret.put(rightJustify(to!string(time.hour), 2, '0'));
        ret.put(":");
        ret.put(rightJustify(to!string(time.minute), 2, '0'));
        ret.put(":");
        ret.put(rightJustify(to!string(time.second), 2, '0'));

        if (tz_offset == 0)
        {
            ret.put(" GMT");
        }
        else
        {
            ret.put(" " ~ (tz_offset >= 0 ? "+" : "-"));

            if (tz_offset < 0) tz_offset = -tz_offset;
            ret.put(rightJustify(to!string(tz_offset / 60), 2, '0'));
            ret.put(rightJustify(to!string(tz_offset % 60), 2, '0'));
        }

        return ret.data;
    }    
}