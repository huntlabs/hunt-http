module hunt.http.Cookie;

import hunt.collection.List;
import hunt.Exceptions;
import hunt.text.Common;
import hunt.util.StringBuilder;
import hunt.text.StringUtils;
import hunt.util.DateTime;

import std.array;
import std.container.array;
import std.conv;
import std.datetime;
import std.string;

import core.stdc.stdio;
import core.stdc.time;

alias HttpCookie = Cookie;

/**
 * An HttpCookie object represents an HTTP cookie, which carries state
 * information between server and user agent. Cookie is widely adopted
 * to create stateful sessions.
 *
 * <p> There are 3 HTTP cookie specifications:
 * <blockquote>
 *   Netscape draft<br>
 *   RFC 2109 - <a href="http://www.ietf.org/rfc/rfc2109.txt">
 * <i>http://www.ietf.org/rfc/rfc2109.txt</i></a><br>
 *   RFC 2965 - <a href="http://www.ietf.org/rfc/rfc2965.txt">
 * <i>http://www.ietf.org/rfc/rfc2965.txt</i></a>
 * </blockquote>
 *
 * <p> HttpCookie class can accept all these 3 forms of syntax.
 *
 * @author Edward Wang
 */
class Cookie {

    // Since the positive and zero max-age have their meanings,
    // this value serves as a hint as 'not specify max-age'
    private enum MAX_AGE_UNSPECIFIED = -1;
    //
    // The value of the cookie itself.
    //

    private string name; // NAME= ... "$Name" style is reserved
    private string value; // value of NAME

    //
    // Attributes encoded in the header's cookie fields.
    //

    private string comment; // ;Comment=VALUE ... describes cookie's use
    // ;Discard ... implied by maxAge < 0
    private string domain; // ;Domain=VALUE ... domain that sees cookie
    private int maxAge = MAX_AGE_UNSPECIFIED; // ;Max-Age=VALUE ... cookies auto-expire
    private string path; // ;Path=VALUE ... URLs that see the cookie
    private bool secure; // ;Secure ... e.g. use SSL
    private int _version = 1; // ;Version=1 ... means RFC 2109++ style
    private bool _isHttpOnly = false;

    // Hold the creation time (in seconds) of the http cookie for later
    // expiration calculation
    private long whenCreated;

    // date formats used by Netscape's cookie draft
    // as well as formats seen on various sites
    private enum string[] COOKIE_DATE_FORMATS = [
        "EEE',' dd-MMM-yyyy HH:mm:ss 'GMT'",
        "EEE',' dd MMM yyyy HH:mm:ss 'GMT'",
        "EEE MMM dd yyyy HH:mm:ss 'GMT'Z",
        "EEE',' dd-MMM-yy HH:mm:ss 'GMT'",
        "EEE',' dd MMM yy HH:mm:ss 'GMT'",
        "EEE MMM dd yy HH:mm:ss 'GMT'Z"
    ];	

    this() {

    }

    /**
     * Constructs a cookie with the specified name and value.
     *
     * <p>
     * The name must conform to RFC 2109. However, vendors may provide a
     * configuration option that allows cookie names conforming to the original
     * Netscape Cookie Specification to be accepted.
     *
     * <p>
     * The name of a cookie cannot be changed once the cookie has been created.
     *
     * <p>
     * The value can be anything the server chooses to send. Its value is
     * probably of interest only to the server. The cookie's value can be
     * changed after creation with the <code>setValue</code> method.
     *
     * <p>
     * By default, cookies are created according to the Netscape cookie
     * specification. The version can be changed with the
     * <code>setVersion</code> method.
     *
     * @param name
     *            the name of the cookie
     *
     * @param value
     *            the value of the cookie
     *
     * @throws IllegalArgumentException
     *             if the cookie name is null or empty or contains any illegal
     *             characters (for example, a comma, space, or semicolon) or
     *             matches a token reserved for use by the cookie protocol
     *
     * @see #setValue
     * @see #setVersion
     */
    this(string name, string value, int expires=-1, 
        string path = "/", string domain = null, 
        bool secure = false, bool httpOnly = true) {
        if (name.empty) {
            throw new IllegalArgumentException("the cookie name is empty");
        }

        this.name = name;
        this.value = value;
        this.maxAge = expires;
        this.path = path;
        this.secure = secure;
        this.domain = domain;
        this._isHttpOnly = httpOnly;
        this.whenCreated = hunt.util.DateTime.DateTime.currentTimeMillis();
    }

    /**
     * Specifies a comment that describes a cookie's purpose. The comment is
     * useful if the browser presents the cookie to the user. Comments are not
     * supported by Netscape Version 0 cookies.
     *
     * @param purpose
     *            a <code>string</code> specifying the comment to display to the
     *            user
     *
     * @see #getComment
     */
    void setComment(string purpose) {
        comment = purpose;
    }

    /**
     * Returns the comment describing the purpose of this cookie, or
     * <code>null</code> if the cookie has no comment.
     *
     * @return the comment of the cookie, or <code>null</code> if unspecified
     *
     * @see #setComment
     */
    string getComment() {
        return comment;
    }

    /**
     *
     * Specifies the domain within which this cookie should be presented.
     *
     * <p>
     * The form of the domain name is specified by RFC 2109. A domain name
     * begins with a dot (<code>.foo.com</code>) and means that the cookie is
     * visible to servers in a specified Domain Name System (DNS) zone (for
     * example, <code>www.foo.com</code>, but not <code>a.b.foo.com</code>). By
     * default, cookies are only returned to the server that sent them.
     *
     * @param domain
     *            the domain name within which this cookie is visible; form is
     *            according to RFC 2109
     *
     * @see #getDomain
     */
    void setDomain(string domain) {
        this.domain = domain.toLower(); // IE allegedly needs
                                                            // this
    }

    /**
     * Gets the domain name of this Cookie.
     *
     * <p>
     * Domain names are formatted according to RFC 2109.
     *
     * @return the domain name of this Cookie
     *
     * @see #setDomain
     */
    string getDomain() nothrow {
        return domain;
    }

    /**
     * Sets the maximum age in seconds for this Cookie.
     *
     * <p>
     * A positive value indicates that the cookie will expire after that many
     * seconds have passed. Note that the value is the <i>maximum</i> age when
     * the cookie will expire, not the cookie's current age.
     *
     * <p>
     * A negative value means that the cookie is not stored persistently and
     * will be deleted when the Web browser exits. A zero value causes the
     * cookie to be deleted.
     *
     * @param expiry
     *            an integer specifying the maximum age of the cookie in
     *            seconds; if negative, means the cookie is not stored; if zero,
     *            deletes the cookie
     *
     * @see #getMaxAge
     */
    void setMaxAge(int expiry) {
        maxAge = expiry;
    }

    /**
     * Gets the maximum age in seconds of this Cookie.
     *
     * <p>
     * By default, <code>-1</code> is returned, which indicates that the cookie
     * will persist until browser shutdown.
     *
     * @return an integer specifying the maximum age of the cookie in seconds;
     *         if negative, means the cookie persists until browser shutdown
     *
     * @see #setMaxAge
     */
    int getMaxAge() {
        return maxAge;
    }

    /**
     * Specifies a path for the cookie to which the client should return the
     * cookie.
     *
     * <p>
     * The cookie is visible to all the pages in the directory you specify, and
     * all the pages in that directory's subdirectories. A cookie's path, for
     * example, <i>/catalog</i>, which makes the cookie visible to all
     * directories on the server under <i>/catalog</i>.
     *
     * <p>
     * Consult RFC 2109 (available on the Internet) for more information on
     * setting path names for cookies.
     *
     *
     * @param uri
     *            a <code>string</code> specifying a path
     *
     * @see #getPath
     */
    void setPath(string uri) {
        path = uri;
    }

    /**
     * Returns the path on the server to which the browser returns this cookie.
     * The cookie is visible to all subpaths on the server.
     *
     * @return a <code>string</code> specifying a path , for example,
     *         <i>/catalog</i>
     *
     * @see #setPath
     */
    string getPath() nothrow {
        return path;
    }

    /**
     * Indicates to the browser whether the cookie should only be sent using a
     * secure protocol, such as HTTPS or SSL.
     *
     * <p>
     * The default value is <code>false</code>.
     *
     * @param flag
     *            if <code>true</code>, sends the cookie from the browser to the
     *            server only when using a secure protocol; if
     *            <code>false</code>, sent on any protocol
     *
     * @see #getSecure
     */
    void setSecure(bool flag) {
        secure = flag;
    }

    /**
     * Returns <code>true</code> if the browser is sending cookies only over a
     * secure protocol, or <code>false</code> if the browser can send cookies
     * using any protocol.
     *
     * @return <code>true</code> if the browser uses a secure protocol,
     *         <code>false</code> otherwise
     *
     * @see #setSecure
     */
    bool getSecure() {
        return secure;
    }

    void setName(string name) {
        this.name = name;
    }

    /**
     * Returns the name of the cookie. The name cannot be changed after
     * creation.
     *
     * @return the name of the cookie
     */
    string getName() nothrow {
        return name;
    }

    /**
     * Assigns a new value to this Cookie.
     * 
     * <p>
     * If you use a binary value, you may want to use BASE64 encoding.
     *
     * <p>
     * With Version 0 cookies, values should not contain white space, brackets,
     * parentheses, equals signs, commas, double quotes, slashes, question
     * marks, at signs, colons, and semicolons. Empty values may not behave the
     * same way on all browsers.
     *
     * @param newValue
     *            the new value of the cookie
     *
     * @see #getValue
     */
    void setValue(string newValue) {
        value = newValue;
    }

    /**
     * Gets the current value of this Cookie.
     *
     * @return the current value of this Cookie
     *
     * @see #setValue
     */
    string getValue() {
        return value;
    }

    /**
     * Returns the version of the protocol this cookie complies with. Version 1
     * complies with RFC 2109, and version 0 complies with the original cookie
     * specification drafted by Netscape. Cookies provided by a browser use and
     * identify the browser's cookie version.
     * 
     * @return 0 if the cookie complies with the original Netscape
     *         specification; 1 if the cookie complies with RFC 2109
     *
     * @see #setVersion
     */
    int getVersion() {
        return _version;
    }

    /**
     * Sets the version of the cookie protocol that this Cookie complies with.
     *
     * <p>
     * Version 0 complies with the original Netscape cookie specification.
     * Version 1 complies with RFC 2109.
     *
     * <p>
     * Since RFC 2109 is still somewhat new, consider version 1 as experimental;
     * do not use it yet on production sites.
     *
     * @param v
     *            0 if the cookie should comply with the original Netscape
     *            specification; 1 if the cookie should comply with RFC 2109
     *
     * @see #getVersion
     */
    void setVersion(int v) {
        _version = v;
    }

    /**
     * Overrides the standard <code>java.lang.Object.clone</code> method to
     * return a copy of this Cookie.
     */
    // Object clone() {
    // 	try {
    // 		return super.clone();
    // 	} catch (NotSupportedException e) {
    // 		throw new RuntimeException(e.getMessage());
    // 	}
    // }

    /**
     * Marks or unmarks this Cookie as <i>HttpOnly</i>.
     *
     * <p>
     * If <tt>isHttpOnly</tt> is set to <tt>true</tt>, this cookie is marked as
     * <i>HttpOnly</i>, by adding the <tt>HttpOnly</tt> attribute to it.
     *
     * <p>
     * <i>HttpOnly</i> cookies are not supposed to be exposed to client-side
     * scripting code, and may therefore help mitigate certain kinds of
     * cross-site scripting attacks.
     *
     * @param isHttpOnly
     *            true if this cookie is to be marked as <i>HttpOnly</i>, false
     *            otherwise
     *
     */
    void setHttpOnly(bool isHttpOnly) {
        this._isHttpOnly = isHttpOnly;
    }

    /**
     * Checks whether this Cookie has been marked as <i>HttpOnly</i>.
     *
     * @return true if this Cookie has been marked as <i>HttpOnly</i>, false
     *         otherwise
     *
     */
    bool isHttpOnly() {
        return _isHttpOnly;
    }

    /**
     * Reports whether this HTTP cookie has expired or not.
     *
     * @return  {@code true} to indicate this HTTP cookie has expired;
     *          otherwise, {@code false}
     */
    bool isExpired() {
        // if not specify max-age, this cookie should be
        // discarded when user agent is to be closed, but
        // it is not expired.
        if (maxAge < 0) return false;
        if (maxAge == 0) return true;

        long deltaSecond = (hunt.util.DateTime.DateTime.currentTimeMillis() - whenCreated) / 1000;
        return deltaSecond > maxAge;
    }

    override
    string toString() {
        return "Cookie [name=" ~ name ~ ", value=" ~ value ~ ", comment=" ~ comment ~ 
            ", domain=" ~ domain ~ ", maxAge=" ~ maxAge.to!string ~ ", path=" ~ path ~ ", secure=" ~ 
            to!string(secure) ~  ", version=" ~ to!string(_version) ~ ", isHttpOnly=" ~ 
            to!string(_isHttpOnly) ~ "]";
    }

}

/* ----------------------------- CookieGenerator ---------------------------- */

string generateCookies(Cookie[] cookies) {
    if (cookies is null) {
        throw new IllegalArgumentException("the cookie list is null");
    }

    if (cookies.length == 1) {
        return generateCookie(cookies[0]);
    } else if (cookies.length > 1) {
        StringBuilder sb = new StringBuilder();

        sb.append(generateCookie(cookies[0]));
        for (size_t i = 1; i < cookies.length; i++) {
            sb.append(';').append(generateCookie(cookies[i]));
        }

        return sb.toString();
    } else {
        throw new IllegalArgumentException("the cookie list size is 0");
    }
}

string generateCookies(List!Cookie cookies) {
    if (cookies is null) {
        throw new IllegalArgumentException("the cookie list is null");
    }

    if (cookies.size() == 1) {
        return generateCookie(cookies.get(0));
    } else if (cookies.size() > 1) {
        StringBuilder sb = new StringBuilder();

        sb.append(generateCookie(cookies.get(0)));
        for (int i = 1; i < cookies.size(); i++) {
            sb.append(';').append(generateCookie(cookies.get(i)));
        }

        return sb.toString();
    } else {
        throw new IllegalArgumentException("the cookie list size is 0");
    }
}

string generateCookie(Cookie cookie) {
    if (cookie is null) {
        throw new IllegalArgumentException("the cookie is null");
    } else {
        return cookie.getName() ~ "=" ~ cookie.getValue();
    }
}

string generateSetCookie(Cookie cookie) {
    if (cookie is null) {
        throw new IllegalArgumentException("the cookie is null");
    } else {
        StringBuilder sb = new StringBuilder();

        sb.append(cookie.getName()).append('=').append(cookie.getValue());

        if (!empty(cookie.getComment())) {
            sb.append(";Comment=").append(cookie.getComment());
        }

        if (!empty(cookie.getDomain())) {
            sb.append(";Domain=").append(cookie.getDomain());
        }
        if (cookie.getMaxAge() >= 0) {
            sb.append(";Max-Age=").append(cookie.getMaxAge());
        }

        string path = empty(cookie.getPath()) ? "/" : cookie.getPath();
        sb.append(";Path=").append(path);

        if (cookie.getSecure()) {
            sb.append(";Secure");
        }

        sb.append(";Version=").append(cookie.getVersion());

        return sb.toString();
    }
}

// string generateServletSetCookie(javax.servlet.http.Cookie cookie) {
// 	if (cookie == null) {
// 		throw new IllegalArgumentException("the cookie is null");
// 	} else {
// 		StringBuilder sb = new StringBuilder();

// 		sb.append(cookie.getName()).append('=').append(cookie.getValue());

// 		if (VerifyUtils.isNotEmpty(cookie.getComment())) {
// 			sb.append(";Comment=").append(cookie.getComment());
// 		}

// 		if (VerifyUtils.isNotEmpty(cookie.getDomain())) {
// 			sb.append(";Domain=").append(cookie.getDomain());
// 		}
// 		if (cookie.getMaxAge() >= 0) {
// 			sb.append(";Max-Age=").append(cookie.getMaxAge());
// 		}

// 		string path = VerifyUtils.isEmpty(cookie.getPath()) ? "/" : cookie.getPath();
// 		sb.append(";Path=").append(path);

// 		if (cookie.getSecure()) {
// 			sb.append(";Secure");
// 		}

// 		sb.append(";Version=").append(cookie.getVersion());

// 		return sb.toString();
// 	}
// }

/* ------------------------------ CookieParser ------------------------------ */

alias CookieParsingHandler = void delegate(string name, string value);

void parseCookies(string cookieStr, CookieParsingHandler callback) {
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

Cookie parseSetCookie(string cookieStr) {
    Cookie cookie = new Cookie();

    parseCookies(cookieStr, (name, value) {
        
        if("expires".equalsIgnoreCase(name)) {
            // "Mon, 20-Apr-2020 12:25:04 GMT"
            char[3] week;
            char[3] month;
            tm t;
            int r = sscanf(value.ptr, "%3s, %2d-%3s-%4d %2d:%2d:%2d GMT", week.ptr,
                    &t.tm_mday, month.ptr, &t.tm_year, &t.tm_hour, &t.tm_min, &t.tm_sec);
            if(r == 7) {
                t.tm_mon = monthByName(cast(string) month);
                t.tm_wday = weekDayByName(cast(string) week);
                
                SysTime dt = SysTime(std.datetime.DateTime(t.tm_year, t.tm_mon, 
                    t.tm_mday, t.tm_hour, t.tm_min, t.tm_sec), UTC());
                SysTime now = Clock.currTime();
                Duration dur = dt - Clock.currTime();
                long sec = dur.total!"seconds"();
                cookie.setMaxAge(cast(int)sec);
            } else {
                // FIXME: Needing refactor or cleanup -@zhangxueping at 2020-04-21T09:38:27+08:00
                // 				
                // int sec;
                // r = sscanf(str.ptr, "%d", &sec);
                // if(r == 1) {
                // 	SysTime now = Clock.currTime();
                // 	cookie.setMaxAge(sec);
                // }
            }
            
        } else if("HttpOnly".equalsIgnoreCase(name)) {
            cookie.setHttpOnly(true);
        } else if ("Comment".equalsIgnoreCase(name)) {
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

Cookie[] parseCookie(string cookieStr) {
    Array!(Cookie) list;
    parseCookies(cookieStr, (name, value) { list.insertBack(new Cookie(name, value)); });
    return list.array();
}

// List<javax.servlet.http.Cookie> parserServletCookie(string cookieStr) {
//     List<javax.servlet.http.Cookie> list = new ArrayList<>();
//     parseCookies(cookieStr, (name, value) -> list.add(new javax.servlet.http.Cookie(name, value)));
//     return list;
// }