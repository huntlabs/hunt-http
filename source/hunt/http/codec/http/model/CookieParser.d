module hunt.http.codec.http.model.CookieParser;

import hunt.http.codec.http.model.Cookie;

import hunt.lang.exception;
import hunt.string;

// import hunt.container.ArrayList;
// import hunt.container.List;

import std.array;
import std.container.array;
import std.conv;
import std.string;

abstract class CookieParser {

    // interface CookieParserCallback {
    //     void cookie(string name, string value);
    // }
    alias CookieParserCallback = void delegate(string name, string value);

    static void parseCookies(string cookieStr, CookieParserCallback callback) {
        if (empty(cookieStr)) {
            throw new IllegalArgumentException("the cookie string is empty");
        } else {
            string[] cookieKeyValues = StringUtils.split(cookieStr, ";");
            foreach (string cookieKeyValue ; cookieKeyValues) {
                string[] kv = StringUtils.split(cookieKeyValue, "=", 2);
                if (kv != null) {
                    if (kv.length == 2) {
                        callback(kv[0].strip(), kv[1].strip());
                    } else if (kv.length == 1) {
                        callback(kv[0].strip(), "");
                    } else {
                        throw new IllegalStateException("the cookie string format error");
                    }
                } else {
                    throw new IllegalStateException("the cookie string format error");
                }
            }
        }
    }

    static Cookie parseSetCookie(string cookieStr) {
        Cookie cookie = new Cookie();
        parseCookies(cookieStr, (name, value) {
            if ("Comment".equalsIgnoreCase(name)) {
                cookie.setComment(value);
            } else if ("Domain".equalsIgnoreCase(name)) {
                cookie.setDomain(value);
            } else if ("Max-Age".equalsIgnoreCase(name)) {
                cookie.setMaxAge(to!int(value));
            } else if ("Path".equalsIgnoreCase(name)) {
                cookie.setPath(value);
            } else if ("Secure".equalsIgnoreCase(name)) {
                cookie.setSecure(true);
            } else if ("Version".equalsIgnoreCase(name)) {
                cookie.setVersion(to!int(value));
            } else {
                cookie.setName(name);
                cookie.setValue(value);
            }

        });
        return cookie;
    }

    static Cookie[] parseCookie(string cookieStr) {
        Array!(Cookie) list;
        parseCookies(cookieStr, (name, value) { list.insertBack(new Cookie(name, value)); });
        return list.array();
    }

    // static List<javax.servlet.http.Cookie> parserServletCookie(string cookieStr) {
    //     List<javax.servlet.http.Cookie> list = new ArrayList<>();
    //     parseCookies(cookieStr, (name, value) -> list.add(new javax.servlet.http.Cookie(name, value)));
    //     return list;
    // }
}
