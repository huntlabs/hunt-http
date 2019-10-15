module hunt.http.codec.http.model.MetaData;

import hunt.collection;

import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.model.HttpField;
import hunt.http.codec.http.model.HttpFields;
import hunt.http.codec.http.model.HostPortHttpField;
import hunt.http.codec.http.model.HttpScheme;
import hunt.net.util.HttpURI;
import hunt.http.HttpVersion;

import hunt.Functions;
import hunt.logging.ConsoleLogger;
import hunt.text.Common;
import hunt.text.StringBuilder;
import hunt.util.Common;

import std.ascii;
import std.format;
import std.range;


// alias HttpRequest = MetaData.Request;
// alias HttpResponse = MetaData.Response;

/**
*/
class MetaData : Iterable!HttpField {
    private HttpVersion _httpVersion;
    private HttpFields _fields;
    private long _contentLength;
    private Supplier!HttpFields _trailers;

    this(HttpVersion ver, HttpFields fields) {
        this(ver, fields, long.min);
    }

    this(HttpVersion ver, HttpFields fields, long contentLength) {
        version(HUNT_HTTP_DEBUG) {
            if(contentLength>0) {
                tracef("version: %s", ver.toString());
                tracef("contentLength: %d", contentLength);
                if(fields !is null) {
                    tracef(fields.toString());
                }
            }
        }
        _httpVersion = ver;
        _fields = fields;
        _contentLength = contentLength;
    }

    protected void recycle() {
        _httpVersion = HttpVersion.Null;
        if (_fields !is null)
            _fields.clear();
        _contentLength = long.min;
    }

    bool isRequest() {
        return false;
    }

    bool isResponse() {
        return false;
    }

    /**
     * @deprecated use {@link #getHttpVersion()} instead
     */
    // deprecated("")
    // HttpVersion getVersion() {
    //     return getHttpVersion();
    // }

    /**
     * @return the HTTP version of this MetaData object
     */
    HttpVersion getHttpVersion() {
        return _httpVersion;
    }

    /**
     * @param httpVersion the HTTP version to set
     */
    void setHttpVersion(HttpVersion httpVersion) {
        _httpVersion = httpVersion;
    }

    /**
     * @return the HTTP fields of this MetaData object
     */
    HttpFields getFields() {
        return _fields;
    }

    Supplier!HttpFields getTrailerSupplier() {
        return _trailers;
    }

    void setTrailerSupplier(Supplier!HttpFields trailers) {
        _trailers = trailers;
    }

    /**
     * @return the content length if available, otherwise {@link Long#MIN_VALUE}
     */
    long getContentLength() {
        if (_contentLength == long.min || _contentLength == -1) {
            if (_fields !is null) {
                HttpField field = _fields.getField(HttpHeader.CONTENT_LENGTH);
                _contentLength = field is null ? -1 : field.getLongValue();
            }
        }
        version(HUNT_HTTP_DEBUG) tracef("contentLength=%d", _contentLength);
        return _contentLength;
    }

    /**
     * @return an iterator over the HTTP fields
     * @see #getFields()
     */
    InputRange!HttpField iterator() {
        return _fields is null ? inputRangeObject(new HttpField[0]) : _fields.iterator();
    }


    int opApply(scope int delegate(ref HttpField) dg)
    {
        int result = 0;
        foreach(HttpField v; _fields)
        {
            result = dg(v);
            if(result != 0) return result;
        }
        return result;
    }

    string[] headers(string name) {
        HttpFields fs = getFields();
        if(fs !is null)
            return fs.getValuesList(name);
        else
            return null;
    }

    string header(string name) {
        return header(name, null);
    }

    string header(string name, string defaultValue) {
        HttpFields fs = getFields();
        string result = fs.get(name);
        return result.empty ? defaultValue : result;
    }

    HttpFields headers() {
        return getFields();
    }    


    override string toString() {
        StringBuilder sb = new StringBuilder();
        foreach (HttpField field ; _fields)
            sb.append(field.toString()).append(std.ascii.newline);
        return sb.toString();
    }

}


/**
*/
class HttpRequest : MetaData {
    private string _method;
    private HttpURI _uri;
    private Object attachment;
    private List!(ByteBuffer) _requestBody; 
    private string _stringBody;

    this(HttpFields fields) {
        this("", null, HttpVersion.Null, fields);
    }

    // this(string method, HttpURI uri, HttpVersion ver, HttpFields fields) {
    //     this(method, uri, ver, fields, long.min);
    // }

    this(string method, HttpURI uri, HttpVersion ver, HttpFields fields, long contentLength=long.min) {
        super(ver, fields, contentLength);
        _method = method;
        _uri = uri;
        
        _requestBody = new ArrayList!(ByteBuffer)();
    }

    // this(string method, HttpScheme scheme, HostPortHttpField hostPort, string uri, HttpVersion ver, HttpFields fields) {
    //     this(method, new HttpURI(scheme.toString(), hostPort.getHost(), hostPort.getPort(), uri), ver, fields);
    // }

    // this(string method, HttpScheme scheme, HostPortHttpField hostPort, string uri, HttpVersion ver, HttpFields fields, long contentLength) {
    //     this(method, new HttpURI( scheme.toString(), hostPort.getHost(), hostPort.getPort(), uri), ver, fields, contentLength);
    // }

    this(string method, string scheme, HostPortHttpField hostPort, string uri, 
            HttpVersion ver, HttpFields fields, long contentLength=long.min) {
        this(method, new HttpURI(scheme, hostPort.getHost(), hostPort.getPort(), uri), ver, fields, contentLength);
    }

    this(HttpRequest request) {
        this(request.getMethod(), new HttpURI(request.getURI()), request.getHttpVersion(), 
            new HttpFields(request.getFields()), request.getContentLength());
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

    bool isHttps() {
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

    Object getAttachment() {
        return attachment;
    }

    void setAttachment(Object attachment) {
        this.attachment = attachment;
    }

    string getStringBody(string charset) {
        // FIXME: Needing refactor or cleanup -@zhangxueping at 2019-10-15T09:49:13+08:00
        // 
        if (_stringBody is null) {
            Appender!string buffer;
            foreach(ByteBuffer b; _requestBody) {
                buffer.put(cast(string)b.array);
            }
            _stringBody = buffer.data; // BufferUtils.toString(_requestBody, charset);
        } 
        return _stringBody;
    }

    string getStringBody() {
        return getStringBody("UTF-8");
    }


    override string toString() {
        HttpFields fields = getFields();
        return format("%s{u=%s,%s,h=%d,cl=%d}",
                getMethod(), getURI(), getHttpVersion(), fields is null ? -1 : fields.size(), getContentLength());
    }
}

/**
*/
class HttpResponse : MetaData {
    protected int _status;
    protected string _reason;
    protected string _contentType;

    this() {
        this(HttpVersion.Null, 0, null);
    }

    this(HttpVersion ver, int status, HttpFields fields) {
        this(ver, status, fields, long.min);
    }

    this(HttpVersion ver, int status, HttpFields fields, long contentLength) {
        super(ver, fields, contentLength);
        _status = status;
    }

    this(HttpVersion ver, int status, string reason, HttpFields fields, long contentLength) {
        super(ver, fields, contentLength);
        _reason = reason;
        _status = status;
    }

    override bool isResponse() {
        return true;
    }

    /**
     * @return the HTTP status
     */
    int getStatus() {
        return _status;
    }

    /**
    * @return the HTTP reason
    */
    string getReason() {
        return _reason;
    }

    /**
    * @param status the HTTP status to set
    */
    void setStatus(int status) {
        _status = status;
    }

    /**
    * @param reason the HTTP reason to set
    */
    void setReason(string reason) {
        _reason = reason;
    }

    string getContentType() {
        if (_contentType.empty()) {
            if (_fields !is null) {
                HttpField field = _fields.getField(HttpHeader.CONTENT_TYPE);
                _contentType = field is null ? "" : field.getValue();
            }
        }
        return _contentType;
    }

    alias code = getStatus;
    alias message = getReason;
    
    /**
    * Returns true if the code is in [200..300), which means the request was successfully received,
    * understood, and accepted.
    */
    bool isSuccessful() {
        return _status >= 200 && _status < 300;
    }

    override string toString() {
        HttpFields fields = getFields();
        return format("%s{s=%d,h=%d,cl=%d}", getHttpVersion(), getStatus(), 
            fields is null ? -1 : fields.size(), getContentLength());
    }
}