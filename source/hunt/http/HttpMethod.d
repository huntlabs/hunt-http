module hunt.http.HttpMethod;

import hunt.io.ByteBuffer;
import hunt.text.Common;
import hunt.util.ObjectUtils;

import std.string;


/**
 * 
 */
struct HttpMethod {
    enum HttpMethod Null = HttpMethod("Null");
    enum HttpMethod GET = HttpMethod("GET");
    enum HttpMethod POST = HttpMethod("POST");
    enum HttpMethod HEAD = HttpMethod("HEAD");
    enum HttpMethod PUT = HttpMethod("PUT");
    enum HttpMethod PATCH = HttpMethod("PATCH");
    enum HttpMethod OPTIONS = HttpMethod("OPTIONS");
    enum HttpMethod DELETE = HttpMethod("DELETE");
    enum HttpMethod TRACE = HttpMethod("TRACE");
    enum HttpMethod CONNECT = HttpMethod("CONNECT");
    enum HttpMethod MOVE = HttpMethod("MOVE");
    enum HttpMethod PROXY = HttpMethod("PROXY");
    enum HttpMethod PRI = HttpMethod("PRI");
    enum HttpMethod COPY = HttpMethod("COPY");
    enum HttpMethod LINK = HttpMethod("LINK");
    enum HttpMethod UNLINK = HttpMethod("UNLINK");
    enum HttpMethod PURGE = HttpMethod("PURGE");
    enum HttpMethod LOCK = HttpMethod("LOCK");
    enum HttpMethod UNLOCK = HttpMethod("UNLOCK");
    enum HttpMethod VIEW = HttpMethod("VIEW");

    /* ------------------------------------------------------------ */

    /**
     * Optimized lookup to find a method name and trailing space in a byte array.
     *
     * @param bytes    Array containing ISO-8859-1 characters
     * @param position The first valid index
     * @param limit    The first non valid index
     * @return A HttpMethod if a match or null if no easy match.
     */
    static HttpMethod lookAheadGet(byte[] bytes, int position, int limit) {
        int length = limit - position;
        if (length < 4)
            return HttpMethod.Null;
        switch (bytes[position]) {
            case 'G':
                if (bytes[position + 1] == 'E' && bytes[position + 2] == 'T' && bytes[position + 3] == ' ')
                    return GET;
                break;
            case 'P':
                if (bytes[position + 1] == 'O' && bytes[position + 2] == 'S' && bytes[position + 3] == 'T' && length >= 5 && bytes[position + 4] == ' ')
                    return POST;
                if (bytes[position + 1] == 'U' && bytes[position + 2] == 'T' && bytes[position + 3] == ' ')
                    return PUT;
                if (bytes[position + 1] == 'R' && bytes[position + 2] == 'O' && bytes[position + 3] == 'X' && length >= 6 && bytes[position + 4] == 'Y' && bytes[position + 5] == ' ')
                    return PROXY;
                if (bytes[position + 1] == 'A' && bytes[position + 2] == 'T' && bytes[position + 3] == 'C' && length >= 6 && bytes[position + 4] == 'H' && bytes[position + 5] == ' ')
                    return PATCH;
                if (bytes[position + 1] == 'U' && bytes[position + 2] == 'R' && bytes[position + 3] == 'G' && length >= 6 && bytes[position + 4] == 'E' && bytes[position + 5] == ' ')
                    return PURGE;
                if (bytes[position + 1] == 'R' && bytes[position + 2] == 'I' && bytes[position + 3] == ' ')
                    return PRI;
                break;
            case 'H':
                if (bytes[position + 1] == 'E' && bytes[position + 2] == 'A' && bytes[position + 3] == 'D' && length >= 5 && bytes[position + 4] == ' ')
                    return HEAD;
                break;
            case 'L':
                if (bytes[position + 1] == 'I' && bytes[position + 2] == 'N' && bytes[position + 3] == 'K' && length >= 5 && bytes[position + 4] == ' ')
                    return LINK;
                if (bytes[position + 1] == 'O' && bytes[position + 2] == 'C' && bytes[position + 3] == 'K' && length >= 5 && bytes[position + 4] == ' ')
                    return LOCK;
                break;
            case 'O':
                if (bytes[position + 1] == 'P' && bytes[position + 2] == 'T' && bytes[position + 3] == 'I' && length >= 8 &&
                        bytes[position + 4] == 'O' && bytes[position + 5] == 'N' && bytes[position + 6] == 'S' && bytes[position + 7] == ' ')
                    return OPTIONS;
                break;
            case 'D':
                if (bytes[position + 1] == 'E' && bytes[position + 2] == 'L' && bytes[position + 3] == 'E' && length >= 7 &&
                        bytes[position + 4] == 'T' && bytes[position + 5] == 'E' && bytes[position + 6] == ' ')
                    return DELETE;
                break;
            case 'T':
                if (bytes[position + 1] == 'R' && bytes[position + 2] == 'A' && bytes[position + 3] == 'C' && length >= 6 &&
                        bytes[position + 4] == 'E' && bytes[position + 5] == ' ')
                    return TRACE;
                break;

            case 'C':
                if (bytes[position + 1] == 'O' && bytes[position + 2] == 'N' && bytes[position + 3] == 'N' && length >= 8 &&
                        bytes[position + 4] == 'E' && bytes[position + 5] == 'C' && bytes[position + 6] == 'T' && bytes[position + 7] == ' ')
                    return CONNECT;
                if (bytes[position + 1] == 'O' && bytes[position + 2] == 'P' && bytes[position + 3] == 'Y' && length >= 5 && bytes[position + 4] == ' ')
                    return COPY;
                break;

            case 'M':
                if (bytes[position + 1] == 'O' && bytes[position + 2] == 'V' && bytes[position + 3] == 'E' && length >= 5 && bytes[position + 4] == ' ')
                    return MOVE;
                break;

            case 'U':
                if (bytes[position + 1] == 'N' && bytes[position + 2] == 'L' && bytes[position + 3] == 'I' && length >= 8 &&
                        bytes[position + 4] == 'N' && bytes[position + 5] == 'K' && bytes[position + 6] == ' ')
                    return UNLINK;
                if (bytes[position + 1] == 'N' && bytes[position + 2] == 'L' && bytes[position + 3] == 'O' && length >= 8 &&
                        bytes[position + 4] == 'C' && bytes[position + 5] == 'K' && bytes[position + 6] == ' ')
                    return UNLOCK;
                break;                

            case 'V':
                if (bytes[position + 1] == 'I' && bytes[position + 2] == 'E' && bytes[position + 3] == 'W' && length >= 5 && bytes[position + 4] == ' ')
                    return VIEW;
                break;

            default:
                break;
        }
        return HttpMethod.Null;
    }

    /* ------------------------------------------------------------ */

    /**
     * Optimized lookup to find a method name and trailing space in a byte array.
     *
     * @param buffer buffer containing ISO-8859-1 characters, it is not modified.
     * @return A HttpMethod if a match or null if no easy match.
     */
    static HttpMethod lookAheadGet(ByteBuffer buffer) {
        if (buffer.hasArray())
            return lookAheadGet(buffer.array(), buffer.arrayOffset() + buffer.position(), buffer.arrayOffset() + buffer.limit());

        int l = buffer.remaining();
        if (l >= 4) {
            string key = cast(string)buffer.peek(0, l);
            HttpMethod m = CACHE[key];
            if (m != HttpMethod.Null) {
                int ml = cast(int)m.asString().length;
                if (l > ml && buffer.get(buffer.position() + ml) == ' ')
                    return m;
            }
        }
        return HttpMethod.Null;
    }

    /* ------------------------------------------------------------ */
    __gshared static HttpMethod[string] INSENSITIVE_CACHE;
    __gshared static HttpMethod[string] CACHE;

    static HttpMethod get(string name)
    {
        return CACHE.get(name, HttpMethod.Null);
    }

    static HttpMethod getInsensitive(string name)
    {
        return INSENSITIVE_CACHE.get(name.toLower(), HttpMethod.Null);
    }


    shared static this() {
        foreach (HttpMethod method ; HttpMethod.values())
        {
            INSENSITIVE_CACHE[method.toString().toLower()] = method;
            CACHE[method.toString()] = method;
        }
    }

 
	mixin ValuesMemberTempate!(HttpMethod);

    /* ------------------------------------------------------------ */
    private string _string;
    // private ByteBuffer _buffer;
    private byte[] _bytes;

    /* ------------------------------------------------------------ */
    this(string s) {
        _string = s;
        _bytes = cast(byte[]) s.dup; // StringUtils.getBytes(s);
        // _bytesColonSpace = cast(byte[])(s ~ ": ").dup;
    }


    bool isSame(string s) {
        return s.length != 0 && std.string.icmp(_string, s) == 0;
    }

    string asString() {
        return _string;
    }

    string toString() {
        return _string;
    }

    /* ------------------------------------------------------------ */
    byte[] getBytes() {
        return _bytes;
    }

    /* ------------------------------------------------------------ */
    // ByteBuffer asBuffer() {
    //     return _buffer.asReadOnlyBuffer();
    // }

    /* ------------------------------------------------------------ */

    /**
     * Converts the given string parameter to an HttpMethod
     *
     * @param method the string to get the equivalent HttpMethod from
     * @return the HttpMethod or null if the parameter method is unknown
     */
    static HttpMethod fromString(string method) {
        string m = method.toUpper();
        if(m in CACHE)
            return CACHE[m];
        else
            return HttpMethod.Null;
    }

    static bool invalidatesCache(string method) {
        return method == "POST"
            || method == "PATCH"
            || method == "PUT"
            || method == "DELETE"
            || method == "MOVE";     // WebDAV
    }

    static bool requiresRequestBody(string method) {
        return method == "POST"
            || method == "PUT"
            || method == "PATCH"
            || method == "PROPPATCH" // WebDAV
            || method == "REPORT";   // CalDAV/CardDAV (defined in WebDAV Versioning)
    }

    static bool permitsRequestBody(string method) {
        return (method != "GET" && method != "HEAD");
    }

    static bool redirectsWithBody(string method) {
        return method == "PROPFIND"; // (WebDAV) redirects should also maintain the request body
    }

    static bool redirectsToGet(string method) {
        // All requests but PROPFIND should redirect to a GET request.
        return method != "PROPFIND";
    }    
}
