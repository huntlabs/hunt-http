module hunt.http.client.MemoryCookieStore;

import hunt.http.client.CookieStore;

import hunt.http.Cookie;
import hunt.collection.TreeSet;
import hunt.util.Comparator;

import core.sync.rwmutex;

import std.algorithm;
import std.datetime;
import std.range;
import std.string;

/**
 * Default implementation of {@link CookieStore}
 */
class MemoryCookieStore : CookieStore {

    private TreeSet!Cookie cookies;
    private ReadWriteMutex lock;

    this() {
        this.cookies = new TreeSet!Cookie(new CookieIdentityComparator());
        this.lock = new ReadWriteMutex();
    }

    /**
     * Adds an {@link Cookie HTTP cookie}, replacing any existing equivalent cookies.
     * If the given cookie has already expired it will not be added, but existing
     * values will still be removed.
     *
     * @param cookie the {@link Cookie cookie} to be added
     *
     * @see #addCookies(Cookie[])
     *
     */
    void addCookie(Cookie cookie) {
        if (cookie !is null) {
            lock.writer().lock();
            scope(exit) lock.writer().unlock();

            // first remove any old cookie that is equivalent
            cookies.remove(cookie);
            if (!cookie.isExpired(Clock.currTime())) {
                cookies.add(cookie);
            }
           
        }
    }

    /**
     * Adds an array of {@link Cookie HTTP cookies}. Cookies are added individually and
     * in the given array order. If any of the given cookies has already expired it will
     * not be added, but existing values will still be removed.
     *
     * @param cookies the {@link Cookie cookies} to be added
     *
     * @see #addCookie(Cookie)
     *
     */
    void addCookies(Cookie[] cookies) {
        if (cookies != null) {
            foreach (Cookie cookie; cookies) {
                this.addCookie(cookie);
            }
        }
    }

    /**
     * Returns an immutable array of {@link Cookie cookies} that this HTTP
     * state currently contains.
     *
     * @return an array of {@link Cookie cookies}.
     */
    Cookie[] getCookies() {
        lock.reader().lock();
        scope(exit) lock.reader().unlock();

        //create defensive copy so it won't be concurrently modified
        return cookies.toArray();
    }

    /**
     * Removes all of {@link Cookie cookies} in this HTTP state
     * that have expired by the specified {@link java.util.Date date}.
     *
     * @return true if any cookies were purged.
     *
     * @see Cookie#isExpired(time)
     */
    bool clearExpired(SysTime time) {

        lock.writer().lock();
        scope(exit) lock.writer().unlock();

        scope Cookie[] tempCookies;
        foreach (Cookie it; cookies) {
            if (it.isExpired(time)) {
                tempCookies ~= it;
            }
        }

        foreach(Cookie c; tempCookies) {
            cookies.remove(c);
        }

        return tempCookies.length > 0;
    }

    /**
     * Clears all cookies.
     */
    void clear() {
        lock.writer().lock();
        scope(exit) lock.writer().unlock();
        cookies.clear();
    }

    override string toString() {
        lock.reader().lock();
        scope(exit) lock.reader().unlock();
        return cookies.toString();
    }

}



/**
 * This cookie comparator can be used to compare identity of cookies.
 * <p>
 * Cookies are considered identical if their names are equal and
 * their domain attributes match ignoring case.
 * </p>
 *
 */
class CookieIdentityComparator : Comparator!Cookie {

    int compare(Cookie c1, Cookie c2) nothrow {
        int res = cmp(c1.getName(), c2.getName());  // c1.getName().compareTo(c2.getName());
        if (res == 0) {
            // do not differentiate empty and null domains
            string d1 = c1.getDomain();
            if (d1 is null) {
                d1 = "";
            } else if (d1.indexOf('.') == -1) {
                d1 = d1 ~ ".local";
            }
            string d2 = c2.getDomain();
            if (d2.empty()) {
                d2 = "";
            } else if (d2.indexOf('.') == -1) {
                d2 = d2 ~ ".local";
            }
            res = icmp(d1, d2);
        }
        if (res == 0) {
            string p1 = c1.getPath();
            if (p1.empty()) {
                p1 = "/";
            }
            string p2 = c2.getPath();
            if (p2.empty()) {
                p2 = "/";
            }
            res = cmp(p1, p2);
        }
        return res;
    }

}
