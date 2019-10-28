module hunt.http.client.CookieStore;

import hunt.http.Cookie;

import std.datetime;

/**
 * This interface represents an abstract store for {@link Cookie}
 * objects.
 *
 */
interface CookieStore {

    /**
     * Adds an {@link Cookie}, replacing any existing equivalent cookies.
     * If the given cookie has already expired it will not be added, but existing
     * values will still be removed.
     *
     * @param cookie the {@link Cookie cookie} to be added
     */
    void addCookie(Cookie cookie);

    /**
     * Returns all cookies contained in this store.
     *
     * @return all cookies
     */
    Cookie[] getCookies();

    /**
     * Removes all of {@link Cookie}s in this store that have expired by
     * the specified SysTime.
     *
     * @return true if any cookies were purged.
     */
    bool clearExpired(SysTime time);

    /**
     * Clears all cookies.
     */
    void clear();

}
