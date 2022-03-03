module hunt.http.client.InMemoryCookieStore;

import hunt.http.client.CookieStore;

import hunt.http.Cookie;
import hunt.collection;
import hunt.Exceptions;
import hunt.logging;
import hunt.util.Comparator;
import hunt.net.util.HttpURI;

import core.sync.rwmutex;

import std.algorithm;
import std.range;
import std.string;

/**
 * A simple in-memory CookieStore implementation
 *
 * @author Edward Wang
 */
class InMemoryCookieStore : CookieStore {

    // the in-memory representation of cookies
    private List!HttpCookie cookieJar;

    // the cookies are indexed by its domain and associated uri (if present)
    // CAUTION: when a cookie removed from main data structure (i.e. cookieJar),
    //          it won't be cleared in domainIndex & uriIndex. Double-check the
    //          presence of cookie when retrieve one form index store.
    // private Map!(string, List!HttpCookie) domainIndex;
    private Map!(string, List!HttpCookie) uriIndex;

    private ReadWriteMutex lock;

    this() {
        cookieJar = new ArrayList!HttpCookie();
        uriIndex = new HashMap!(string, List!HttpCookie)();
        this.lock = new ReadWriteMutex();
    }

    /**
     * Add one cookie into cookie store.
     */
    void add(HttpURI uri, HttpCookie cookie) {
        if (cookie is null) {
            throw new NullPointerException("cookie is null");
        }

        if (uri is null) {
            throw new NullPointerException("uri is null");
        }

        lock.writer().lock();
        scope(exit) lock.writer().unlock();

        // remove the ole cookie if there has had one
        cookieJar.remove(cookie);

        // add new cookie if it has a non-zero max-age
        if (!cookie.isExpired()) {
            cookieJar.add(cookie);
            // and add it to domain index
            // string domain = cookie.getDomain();
            // if (!domain.empty()) {
            //     addIndex(domainIndex, domain, cookie);
            // }

            // add it to uri index, too
            addIndex(uriIndex, getEffectiveURI(uri), cookie);
        }        
    }


    /**
     * Get all cookies, which:
     *  1) given uri domain-matches with, or, associated with
     *     given uri when added to the cookie store.
     *  3) not expired.
     * See RFC 2965 sec. 3.3.4 for more detail.
     */
    HttpCookie[] get(string uri) {
        // argument can't be null
        if (uri.empty()) {
            throw new NullPointerException("uri is null");
        }

        HttpURI httpUri = new HttpURI(uri);
        bool secureLink = icmp("https", httpUri.getScheme()) == 0;

        lock.reader().lock();
        scope(exit) lock.reader().unlock();

        List!(HttpCookie) cookies = new ArrayList!HttpCookie();
        try {
            // check domainIndex first
            // getInternal1(cookies, domainIndex, httpUri.getHost(), secureLink);
            // check uriIndex then
            getInternal2(cookies, uriIndex, getEffectiveURI(httpUri), secureLink);
        } catch(Exception ex ) {
            debug warning(ex.msg);
        }

        return cookies.toArray();
    }

    /**
     * Get all cookies in cookie store, except those have expired
     */
    HttpCookie[] getCookies() {
        lock.reader().lock();
        scope(exit) lock.reader().unlock();

        try {
            HttpCookie[] expiredCookies;
            foreach(HttpCookie c; cookieJar) {
                if(c.isExpired()) {
                    expiredCookies ~= c;
                }
            }
            foreach(HttpCookie c; expiredCookies) {
                cookieJar.remove(c);
            }
        } catch(Exception ex) {
            debug warning(ex.msg);
        }

        return cookieJar.toArray[];
    }

    /**
     * Get all URIs, which are associated with at least one cookie
     * of this cookie store.
     */
    string[] getURIs() {
        lock.reader().lock();
        scope(exit) lock.reader().unlock();
        return uriIndex.byKey().array();
    }


    /**
     * Remove a cookie from store
     */
    bool remove(string uri, HttpCookie cookie) {
        // argument can't be null
        if (cookie is null) {
            throw new NullPointerException("cookie is null");
        }
        lock.writer().lock();
        scope(exit) lock.writer().unlock();

        return cookieJar.remove(cookie);
    }


    /**
     * Remove all cookies in this cookie store.
     */
    bool removeAll() {
        lock.writer().lock();
        scope(exit) lock.writer().unlock();

        if (cookieJar.isEmpty()) {
            return false;
        }
        cookieJar.clear();
        // domainIndex.clear();
        uriIndex.clear();

        return true;
    }

    /**
     * Removes all of {@link Cookie cookies} in this HTTP state
     * that have expired by the specified {@link java.util.Date date}.
     *
     * @return true if any cookies were purged.
     *
     * @see Cookie#isExpired(time)
     */
    bool clearExpired() {
        lock.writer().lock();
        scope(exit) lock.writer().unlock();

        scope Cookie[] tempCookies;
        foreach (Cookie it; cookieJar) {
            if (it.isExpired()) {
                tempCookies ~= it;
            }
        }

        foreach(Cookie c; tempCookies) {
            cookieJar.remove(c);
        }


        return tempCookies.length > 0;
    }
    /* ---------------- Private operations -------------- */


    /*
     * This is almost the same as HttpCookie.domainMatches except for
     * one difference: It won't reject cookies when the 'H' part of the
     * domain contains a dot ('.').
     * I.E.: RFC 2965 section 3.3.2 says that if host is x.y.domain.com
     * and the cookie domain is .domain.com, then it should be rejected.
     * However that's not how the real world works. Browsers don't reject and
     * some sites, like yahoo.com do actually expect these cookies to be
     * passed along.
     * And should be used for 'old' style cookies (aka Netscape type of cookies)
     */
    // private bool netscapeDomainMatches(String domain, String host)
    // {
    //     if (domain is null || host is null) {
    //         return false;
    //     }

    //     // if there's no embedded dot in domain and domain is not .local
    //     bool isLocalDomain = ".local".equalsIgnoreCase(domain);
    //     int embeddedDotInDomain = domain.indexOf('.');
    //     if (embeddedDotInDomain == 0) {
    //         embeddedDotInDomain = domain.indexOf('.', 1);
    //     }
    //     if (!isLocalDomain && (embeddedDotInDomain == -1 || embeddedDotInDomain == domain.length() - 1)) {
    //         return false;
    //     }

    //     // if the host name contains no dot and the domain name is .local
    //     int firstDotInHost = host.indexOf('.');
    //     if (firstDotInHost == -1 && isLocalDomain) {
    //         return true;
    //     }

    //     int domainLength = domain.length();
    //     int lengthDiff = host.length() - domainLength;
    //     if (lengthDiff == 0) {
    //         // if the host name and the domain name are just string-compare euqal
    //         return host.equalsIgnoreCase(domain);
    //     } else if (lengthDiff > 0) {
    //         // need to check H & D component
    //         String H = host.substring(0, lengthDiff);
    //         String D = host.substring(lengthDiff);

    //         return (D.equalsIgnoreCase(domain));
    //     } else if (lengthDiff == -1) {
    //         // if domain is actually .host
    //         return (domain.charAt(0) == '.' &&
    //                 host.equalsIgnoreCase(domain.substring(1)));
    //     }

    //     return false;
    // }

    // private void getInternal1(List!(HttpCookie) cookies, Map!(String, List!(HttpCookie)) cookieIndex,
    //         String host, bool secureLink) {
    //     // Use a separate list to handle cookies that need to be removed so
    //     // that there is no conflict with iterators.
    //     ArrayList!(HttpCookie) toRemove = new ArrayList<>();
    //     for (Map.Entry!(String, List!(HttpCookie)) entry : cookieIndex.entrySet()) {
    //         String domain = entry.getKey();
    //         List!(HttpCookie) lst = entry.getValue();
    //         for (HttpCookie c : lst) {
    //             if ((c.getVersion() == 0 && netscapeDomainMatches(domain, host)) ||
    //                     (c.getVersion() == 1 && HttpCookie.domainMatches(domain, host))) {
    //                 if ((cookieJar.indexOf(c) != -1)) {
    //                     // the cookie still in main cookie store
    //                     if (!c.hasExpired()) {
    //                         // don't add twice and make sure it's the proper
    //                         // security level
    //                         if ((secureLink || !c.getSecure()) &&
    //                                 !cookies.contains(c)) {
    //                             cookies.add(c);
    //                         }
    //                     } else {
    //                         toRemove.add(c);
    //                     }
    //                 } else {
    //                     // the cookie has beed removed from main store,
    //                     // so also remove it from domain indexed store
    //                     toRemove.add(c);
    //                 }
    //             }
    //         }
    //         // Clear up the cookies that need to be removed
    //         for (HttpCookie c : toRemove) {
    //             lst.remove(c);
    //             cookieJar.remove(c);

    //         }
    //         toRemove.clear();
    //     }
    // }

    // @param cookies           [OUT] contains the found cookies
    // @param cookieIndex       the index
    // @param key        the prediction to decide whether or not
    //                          a cookie in index should be returned
    private void getInternal2(List!(HttpCookie) cookies,
                                Map!(string, List!(HttpCookie)) cookieIndex,
                                string key, bool secureLink)
    {
        foreach (string index; cookieIndex.byKey()) {
            if (icmp(key, index) != 0) continue;

            List!(HttpCookie) indexedCookies = cookieIndex.get(index);
            // check the list of cookies associated with this domain
            if (indexedCookies is null) 
                continue;

            HttpCookie[] removedCookies;
            foreach(HttpCookie ck; indexedCookies) {
                if (cookieJar.indexOf(ck) != -1) {
                    // the cookie still in main cookie store
                    if (!ck.isExpired()) {
                        // don't add twice
                        if ((secureLink || !ck.getSecure()) &&
                                !cookies.contains(ck))
                            cookies.add(ck);
                    } else {
                        removedCookies ~= ck;
                        cookieJar.remove(ck);
                    }
                } else {
                    // the cookie has beed removed from main store,
                    // so also remove it from domain indexed store
                    removedCookies ~= ck;
                }
            }

            foreach(HttpCookie ck; removedCookies) {
                indexedCookies.remove(ck);
            }
        } // end of cookieIndex iteration
    }

    // add 'cookie' indexed by 'index' into 'indexStore'
    private void addIndex(Map!(string, List!HttpCookie) indexStore,
                              string index,
                              HttpCookie cookie)
    {
        if (!index.empty()) {
            List!(HttpCookie) cookies = indexStore.get(index);
            if (cookies !is null) {
                // there may already have the same cookie, so remove it first
                cookies.remove(cookie);

                cookies.add(cookie);
            } else {
                cookies = new ArrayList!HttpCookie();
                cookies.add(cookie);
                indexStore.put(index, cookies);
            }
        }
    }


    //
    // for cookie purpose, the effective uri should only be http://host
    // the path will be taken into account when path-match algorithm applied
    //
    private string getEffectiveURI(HttpURI uri) {
        HttpURI effectiveURI = new HttpURI("http",
                                   uri.getHost(),
                                   uri.getPort(), 
                                   null  // path component
                                  );

        return effectiveURI.toString();
    }

    // /**
    //  * Adds an array of {@link Cookie HTTP cookies}. Cookies are added individually and
    //  * in the given array order. If any of the given cookies has already expired it will
    //  * not be added, but existing values will still be removed.
    //  *
    //  * @param cookies the {@link Cookie cookies} to be added
    //  *
    //  * @see #addCookie(Cookie)
    //  *
    //  */
    // void addCookies(Cookie[] cookies) {
    //     if (cookies !is null) {
    //         foreach (Cookie cookie; cookies) {
    //             this.addCookie(cookie);
    //         }
    //     }
    // }

    // /**
    //  * Returns an immutable array of {@link Cookie cookies} that this HTTP
    //  * state currently contains.
    //  *
    //  * @return an array of {@link Cookie cookies}.
    //  */
    // Cookie[] getCookies() {
    //     lock.reader().lock();
    //     scope(exit) lock.reader().unlock();

    //     //create defensive copy so it won't be concurrently modified
    //     return cookies.toArray();
    // }

    // /**
    //  * Removes all of {@link Cookie cookies} in this HTTP state
    //  * that have expired by the specified {@link java.util.Date date}.
    //  *
    //  * @return true if any cookies were purged.
    //  *
    //  * @see Cookie#isExpired(time)
    //  */
    // bool clearExpired(SysTime time) {

    //     lock.writer().lock();
    //     scope(exit) lock.writer().unlock();

    //     scope Cookie[] tempCookies;
    //     foreach (Cookie it; cookies) {
    //         if (it.isExpired(time)) {
    //             tempCookies ~= it;
    //         }
    //     }

    //     foreach(Cookie c; tempCookies) {
    //         cookies.remove(c);
    //     }

    //     return tempCookies.length > 0;
    // }

    // /**
    //  * Clears all cookies.
    //  */
    // void clear() {
    //     lock.writer().lock();
    //     scope(exit) lock.writer().unlock();
    //     cookies.clear();
    // }

    // override string toString() {
    //     lock.reader().lock();
    //     scope(exit) lock.reader().unlock();
    //     return cookies.toString();
    // }

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
