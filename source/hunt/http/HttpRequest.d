module hunt.http.HttpRequest;

import hunt.http.HttpField;
import hunt.http.HttpFields;
import hunt.http.HttpHeader;
import hunt.http.HttpMetaData;
import hunt.http.HttpScheme;
import hunt.http.HttpVersion;

import hunt.collection;
import hunt.Functions;
import hunt.Exceptions;
import hunt.logging;
import hunt.net.util.HttpURI;
import hunt.text.Common;
import hunt.util.StringBuilder;
import hunt.util.Common;

import std.ascii;
import std.format;
import std.range;


version(WITH_HUNT_TRACE) {
    import hunt.trace.Tracer;
}

/**
 * 
 */
class HttpRequest : HttpMetaData {
    private string _method;
    private HttpURI _uri;
    private Object[string] _attributes;

    this(HttpFields fields) {
        this("", null, HttpVersion.Null, fields);
    }

    // this(string method, HttpURI uri, HttpVersion ver, HttpFields fields) {
    //     this(method, uri, ver, fields, long.min);
    // }


    this(string method, string scheme, string host, int port, string uri, 
            HttpVersion ver, HttpFields fields, long contentLength=long.min) {
        this(method, new HttpURI(scheme, host, port, uri), ver, fields, contentLength);
    }

    this(HttpRequest request) {
        this(request.getMethod(), new HttpURI(request.getURI()), request.getHttpVersion(), 
            new HttpFields(request.getFields()), request.getContentLength());
    }

    this(string method, HttpURI uri, HttpVersion ver, HttpFields fields, long contentLength=long.min) {
        super(ver, fields, contentLength);
        _method = method;
        _uri = uri;
        
    }

    override void recycle() {
        super.recycle();
        _method = null;
        if (_uri !is null)
            _uri.clear();
    }

    override bool isRequest() {
        return true;
    }
    
    /**
     * Checks whether the request is secure or not.
     *
     * This method can read the client protocol from the "X-Forwarded-Proto" header
     * when trusted proxies were set via "setTrustedProxies()".
     *
     * The "X-Forwarded-Proto" header must contain the protocol: "https" or "http".
     *
     * @return bool
     */
    bool isHttps() {
        // FIXME: Needing refactor or cleanup -@zhangxueping at 2020-04-16T11:28:15+08:00
        // 
        string scheme = _uri.getScheme();
        return scheme == HttpScheme.HTTPS || scheme == HttpScheme.WSS;
    }

    /**
    * @return the HTTP method
    */
    string getMethod() {
        return _method;
    }

    /**
    * @param method the HTTP method to set
    */
    void setMethod(string method) {
        _method = method;
    }

    /**
    * @return the HTTP URI
    */
    HttpURI getURI() {
        return _uri;
    }

    /**
    * @return the HTTP URI in string form
    */
    string getURIString() {
        return _uri is null ? null : _uri.toString();
    }

    /**
    * @param uri the HTTP URI to set
    */
    void setURI(HttpURI uri) {
        _uri = uri;
    }

    bool headerExists(HttpHeader header) {
        return getFields().containsKey(header.asString());
    }

    bool headerExists(string key) {
        return getFields().containsKey(key);
    }

    bool isChunked() {
        string transferEncoding = getFields().get(HttpHeader.TRANSFER_ENCODING);
        return HttpHeaderValue.CHUNKED.asString() == transferEncoding
                || (getHttpVersion() == HttpVersion.HTTP_2 && getContentLength() < 0);
    }

    deprecated("Using getAttribute instead.")
    Object getAttachment() {
        return getAttribute("_attachment");
    }

    deprecated("Using setAttribute instead.")
    void setAttachment(Object attachment) {
        // this.attachment = attachment;
        setAttribute("_attachment", attachment);
    }

    /**
     * Returns the value of the user-defined attribute of this connection.
     *
     * @param key the key of the attribute
     * @return <tt>null</tt> if there is no attribute with the specified key
     */
    Object getAttribute(string key) {
        return getAttribute(key, null);
    }

    /**
     * Returns the value of user defined attribute associated with the
     * specified key.  If there's no such attribute, the specified default
     * value is associated with the specified key, and the default value is
     * returned.  This method is same with the following code except that the
     * operation is performed atomically.
     * <pre>
     * if (containsAttribute(key)) {
     *     return getAttribute(key);
     * } else {
     *     setAttribute(key, defaultValue);
     *     return defaultValue;
     * }
     * </pre>
     * 
     * @param key the key of the attribute we want to retreive
     * @param defaultValue the default value of the attribute
     * @return The retrieved attribute or <tt>null</tt> if not found
     */
    Object getAttribute(string key, Object defaultValue) {
        return _attributes.get(key, defaultValue);
    }

    /**
     * Sets a user-defined attribute.
     *
     * @param key the key of the attribute
     * @param value the value of the attribute
     * @return The old value of the attribute.  <tt>null</tt> if it is new.
     */
    Object setAttribute(string key, Object value) {
        auto itemPtr = key in _attributes;
		Object oldValue = null;
        if(itemPtr !is null) {
            oldValue = *itemPtr;
        }
        _attributes[key] = value;
		return oldValue;
    }

    /**
     * Removes a user-defined attribute with the specified key.
     *
     * @param key The key of the attribute we want to remove
     * @return The old value of the attribute.  <tt>null</tt> if not found.
     */
    Object removeAttribute(string key) {
        auto itemPtr = key in _attributes;
        if(itemPtr is null) {
            return null;
        } else {
            Object oldValue = *itemPtr;
            _attributes.remove(key);
            return oldValue;
        }
    }

    /**
     * @param key The key of the attribute we are looking for in the connection 
     * @return <tt>true</tt> if this connection contains the attribute with
     * the specified <tt>key</tt>.
     */
    bool containsAttribute(string key) {
        auto itemPtr = key in _attributes;
        return itemPtr !is null;
    }

    /**
     * @return the set of keys of all user-defined attributes.
     */
    string[] getAttributeKeys() {
        return _attributes.keys();
    }

    override string toString() {
        HttpFields fields = getFields();
        return format("%s{u=%s,%s,h=%d,cl=%d}",
                getMethod(), getURI(), getHttpVersion(), fields is null ? -1 : fields.size(), getContentLength());
    }

version(WITH_HUNT_TRACE) {
    Tracer tracer;
}

}
