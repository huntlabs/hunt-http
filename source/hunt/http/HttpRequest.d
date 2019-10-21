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
import hunt.logging.ConsoleLogger;
import hunt.net.util.HttpURI;
import hunt.text.Common;
import hunt.text.StringBuilder;
import hunt.util.Common;

import std.ascii;
import std.format;
import std.range;

/**
 * 
 */
class HttpRequest : HttpMetaData {
    private string _method;
    private HttpURI _uri;
    private Object attachment;  

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

    bool isChunked() {
        string transferEncoding = getFields().get(HttpHeader.TRANSFER_ENCODING);
        return HttpHeaderValue.CHUNKED.asString() == transferEncoding
                || (getHttpVersion() == HttpVersion.HTTP_2 && getContentLength() < 0);
    }

    Object getAttachment() {
        return attachment;
    }

    void setAttachment(Object attachment) {
        this.attachment = attachment;
    }

    override string toString() {
        HttpFields fields = getFields();
        return format("%s{u=%s,%s,h=%d,cl=%d}",
                getMethod(), getURI(), getHttpVersion(), fields is null ? -1 : fields.size(), getContentLength());
    }    
}
