module hunt.http.codec.http.model.HttpHeader;

import hunt.util.Traits;
import hunt.logging;

import std.algorithm;
import std.conv;
import std.string;

bool contains(HttpHeader[] items, ref HttpHeader item) {
    return items.canFind(item);
}

/**
*/
struct HttpHeader {
    enum HttpHeader Null = HttpHeader("Null");

    /**
     * General Fields.
     */
    enum HttpHeader CONNECTION = HttpHeader("Connection");
    enum HttpHeader CACHE_CONTROL = HttpHeader("Cache-Control");
    enum HttpHeader DATE = HttpHeader("Date");
    enum HttpHeader PRAGMA = HttpHeader("Pragma");
    enum HttpHeader PROXY_CONNECTION = HttpHeader("Proxy-Connection");
    enum HttpHeader TRAILER = HttpHeader("Trailer");
    enum HttpHeader TRANSFER_ENCODING = HttpHeader("Transfer-Encoding");
    enum HttpHeader UPGRADE = HttpHeader("Upgrade");
    enum HttpHeader VIA = HttpHeader("Via");
    enum HttpHeader WARNING = HttpHeader("Warning");
    enum HttpHeader NEGOTIATE = HttpHeader("Negotiate");

    /**
     * Entity Fields.
     */
    enum HttpHeader ALLOW = HttpHeader("Allow");
    enum HttpHeader CONTENT_DISPOSITION = HttpHeader("Content-Disposition");
    enum HttpHeader CONTENT_ENCODING = HttpHeader("Content-Encoding");
    enum HttpHeader CONTENT_LANGUAGE = HttpHeader("Content-Language");
    enum HttpHeader CONTENT_LENGTH = HttpHeader("Content-Length");
    enum HttpHeader CONTENT_LOCATION = HttpHeader("Content-Location");
    enum HttpHeader CONTENT_MD5 = HttpHeader("Content-MD5");
    enum HttpHeader CONTENT_RANGE = HttpHeader("Content-Range");
    enum HttpHeader CONTENT_TYPE = HttpHeader("Content-Type");
    enum HttpHeader EXPIRES = HttpHeader("Expires");
    enum HttpHeader LAST_MODIFIED = HttpHeader("Last-Modified");

    /**
     * Request Fields.
     */
    enum HttpHeader ACCEPT = HttpHeader("Accept");
    enum HttpHeader ACCEPT_CHARSET = HttpHeader("Accept-Charset");
    enum HttpHeader ACCEPT_ENCODING = HttpHeader("Accept-Encoding");
    enum HttpHeader ACCEPT_LANGUAGE = HttpHeader("Accept-Language");
    enum HttpHeader AUTHORIZATION = HttpHeader("Authorization");
    enum HttpHeader EXPECT = HttpHeader("Expect");
    enum HttpHeader FORWARDED = HttpHeader("Forwarded");
    enum HttpHeader FROM = HttpHeader("From");
    enum HttpHeader HOST = HttpHeader("Host");
    enum HttpHeader IF_MATCH = HttpHeader("If-Match");
    enum HttpHeader IF_MODIFIED_SINCE = HttpHeader("If-Modified-Since");
    enum HttpHeader IF_NONE_MATCH = HttpHeader("If-None-Match");
    enum HttpHeader IF_RANGE = HttpHeader("If-Range");
    enum HttpHeader IF_UNMODIFIED_SINCE = HttpHeader("If-Unmodified-Since");
    enum HttpHeader KEEP_ALIVE = HttpHeader("Keep-Alive");
    enum HttpHeader MAX_FORWARDS = HttpHeader("Max-Forwards");
    enum HttpHeader PROXY_AUTHORIZATION = HttpHeader("Proxy-Authorization");
    enum HttpHeader RANGE = HttpHeader("Range");
    enum HttpHeader REQUEST_RANGE = HttpHeader("Request-Range");
    enum HttpHeader REFERER = HttpHeader("Referer");
    enum HttpHeader TE = HttpHeader("TE");
    enum HttpHeader USER_AGENT = HttpHeader("User-Agent");
    enum HttpHeader X_FORWARDED_FOR = HttpHeader("X-Forwarded-For");
    enum HttpHeader X_FORWARDED_PROTO = HttpHeader("X-Forwarded-Proto");
    enum HttpHeader X_FORWARDED_SERVER = HttpHeader("X-Forwarded-Server");
    enum HttpHeader X_FORWARDED_HOST = HttpHeader("X-Forwarded-Host");

    /**
     * Response Fields.
     */
    enum HttpHeader ACCEPT_RANGES = HttpHeader("Accept-Ranges");
    enum HttpHeader AGE = HttpHeader("Age");
    enum HttpHeader ETAG = HttpHeader("ETag");
    enum HttpHeader LOCATION = HttpHeader("Location");
    enum HttpHeader PROXY_AUTHENTICATE = HttpHeader("Proxy-Authenticate");
    enum HttpHeader RETRY_AFTER = HttpHeader("Retry-After");
    enum HttpHeader SERVER = HttpHeader("Server");
    enum HttpHeader SERVLET_ENGINE = HttpHeader("Servlet-Engine");
    enum HttpHeader VARY = HttpHeader("Vary");
    enum HttpHeader WWW_AUTHENTICATE = HttpHeader("WWW-Authenticate");

    /**
     * WebSocket Fields.
     */
    enum HttpHeader ORIGIN = HttpHeader("Origin");
    enum HttpHeader SEC_WEBSOCKET_KEY = HttpHeader("Sec-WebSocket-Key");
    enum HttpHeader SEC_WEBSOCKET_VERSION = HttpHeader("Sec-WebSocket-Version");
    enum HttpHeader SEC_WEBSOCKET_EXTENSIONS = HttpHeader("Sec-WebSocket-Extensions");
    enum HttpHeader SEC_WEBSOCKET_SUBPROTOCOL = HttpHeader("Sec-WebSocket-Protocol");
    enum HttpHeader SEC_WEBSOCKET_ACCEPT = HttpHeader("Sec-WebSocket-Accept");

    /**
     * Other Fields.
     */
    enum HttpHeader COOKIE = HttpHeader("Cookie");
    enum HttpHeader SET_COOKIE = HttpHeader("Set-Cookie");
    enum HttpHeader SET_COOKIE2 = HttpHeader("Set-Cookie2");
    enum HttpHeader MIME_VERSION = HttpHeader("MIME-Version");
    enum HttpHeader IDENTITY = HttpHeader("identity");

    enum HttpHeader X_POWERED_BY = HttpHeader("X-Powered-By");
    enum HttpHeader HTTP2_SETTINGS = HttpHeader("HTTP2-Settings");

    enum HttpHeader STRICT_TRANSPORT_SECURITY = HttpHeader("Strict-Transport-Security");

    /**
     * HTTP2 Fields.
     */
    enum HttpHeader C_METHOD = HttpHeader(":method");
    enum HttpHeader C_SCHEME = HttpHeader(":scheme");
    enum HttpHeader C_AUTHORITY = HttpHeader(":authority");
    enum HttpHeader C_PATH = HttpHeader(":path");
    enum HttpHeader C_STATUS = HttpHeader(":status");

    enum HttpHeader UNKNOWN = HttpHeader("::UNKNOWN::");

    private __gshared HttpHeader[string] CACHE;

    static bool exists(string name) {
        return (name.toLower() in CACHE) !is null;
    }

    static HttpHeader get(string name) {
        return CACHE.get(name.toLower(), HttpHeader.Null);
    }

    static int getCount() {
        return cast(int) CACHE.length;
    }

    shared static this() {
        int i = 0;
        foreach (ref HttpHeader header; HttpHeader.values()) {
            // header._ordinal = i++;
            if (header != UNKNOWN)
                CACHE[header.asString().toLower()] = header;
        }

        // trace(CACHE);
        // foreach(ref HttpHeader header; HttpHeader.values())
        // {
        //     tracef("xx=%d", header._ordinal);
        // }
    }

    mixin GetConstantValues!(HttpHeader);

    private int _ordinal;
    private string _string;
    private byte[] _bytes;
    private byte[] _bytesColonSpace;
    // private ByteBuffer _buffer;

    this(string s) {
        _string = s;
        _bytes = cast(byte[]) s.dup; // StringUtils.getBytes(s);
        _bytesColonSpace = cast(byte[])(s ~ ": ").dup;
        _ordinal = cast(int) hashOf(s.toLower());
        // _buffer = BufferUtils.toBuffer(_bytes);
    }

    // ByteBuffer toBuffer() {
    //     return _buffer.asReadOnlyBuffer();
    // }

    byte[] getBytes() {
        return _bytes;
    }

    byte[] getBytesColonSpace() {
        return _bytesColonSpace;
    }

    bool isSame(string s) const nothrow {
        return std.string.icmp(_string, s) == 0;
    }

    string asString() const nothrow {
        return _string;
    }

    string toString() {
        return _string;
    }

    int ordinal() {
        return _ordinal;
    }

    size_t toHash() @trusted nothrow {
        return hashOf(_string);
    }

    bool opEquals(const HttpHeader h) nothrow {
        return std.string.cmp(_string, h._string) == 0;
    }

    bool opEquals(ref const HttpHeader h) nothrow {
        return std.string.cmp(_string, h._string) == 0;
    }

    // bool opEquals(const HttpHeader h) const nothrow{
    //     return isSame(h.asString());
    // } 
}
