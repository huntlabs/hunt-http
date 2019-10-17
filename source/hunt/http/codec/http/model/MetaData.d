module hunt.http.codec.http.model.MetaData;

import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.model.HttpField;
import hunt.http.codec.http.model.HttpFields;
import hunt.http.codec.http.model.HttpHeaderValue;
import hunt.http.codec.http.model.HostPortHttpField;
import hunt.http.codec.http.model.HttpScheme;
import hunt.http.codec.http.model.MultipartFormInputStream;
import hunt.http.codec.http.model.MultipartOptions;

import hunt.http.server.HttpRequestOptions;
import hunt.http.server.GlobalSettings;

import hunt.http.HttpVersion;

import hunt.collection;
import hunt.Functions;
import hunt.io.Common;
import hunt.Exceptions;
import hunt.io.PipedStream;
import hunt.logging.ConsoleLogger;
import hunt.net.util.HttpURI;
import hunt.net.util.UrlEncoded;
import hunt.text.Common;
import hunt.text.StringBuilder;
import hunt.util.Common;
import hunt.util.MimeTypeUtils;

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
    protected string _contentType;
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

    string getContentType() {
        if (_contentType.empty()) {
            if (_fields !is null) {
                HttpField field = _fields.getField(HttpHeader.CONTENT_TYPE);
                _contentType = field is null ? "" : field.getValue();
            }
        }
        return _contentType;
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

    /**
     * @return an iterator over the HTTP fields
     * @see #getFields()
     */
    InputRange!HttpField iterator() {
        return _fields is null ? inputRangeObject(new HttpField[0]) : _fields.iterator();
    }


    int opApply(scope int delegate(ref HttpField) dg) {
        int result = 0;
        foreach(HttpField v; _fields)
        {
            result = dg(v);
            if(result != 0) return result;
        }
        return result;
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
    // private List!(ByteBuffer) _requestBody; 
    private string _stringBody; 
    private string _mimeType;

    private PipedStream pipedStream;
    private MultipartFormInputStream multipartFormInputStream;
    private UrlEncoded urlEncodedMap;
    private string charset;

    // private Action1!ByteBuffer _contentHandler;
    private Action1!HttpRequest _contentCompleteHandler;
    private Action1!HttpRequest _messageCompleteHandler;    

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
        
        // _requestBody = new ArrayList!(ByteBuffer)();
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

    bool isChunked() {
        string transferEncoding = getFields().get(HttpHeader.TRANSFER_ENCODING);
        return HttpHeaderValue.CHUNKED.asString() == transferEncoding
                || (getHttpVersion() == HttpVersion.HTTP_2 && getContentLength() < 0);
    }

    string getParameter(string name) {
        decodeUrl();
        return urlEncodedMap.getString(name);
    }

    List!(string) getParameterValues(string name) {
        decodeUrl();
        return urlEncodedMap.getValues(name);
    }

    Map!(string, List!(string)) getParameterMap() {
        decodeUrl();
        return urlEncodedMap;
    }

    string getMimeType() {
        if(_mimeType is null) {
            _mimeType = MimeTypeUtils.getContentTypeMIMEType(getContentType());
        }

        return _mimeType;
    }
    

    private void decodeUrl() {
        if(urlEncodedMap !is null)
            return;

        urlEncodedMap = new UrlEncoded();

        string queryString = _uri.getQuery();
        if (!queryString.empty()) {
            urlEncodedMap.decode(queryString);
        }

        if ("application/x-www-form-urlencoded".equalsIgnoreCase(getMimeType())) {
            HttpRequestOptions _options = GlobalSettings.httpServerOptions.requestOptions();
            string bodyString = getStringBody(_options.getCharset());
            urlEncodedMap.decode(bodyString);
        }
    }

    void setPipedStream(PipedStream stream) {
        this.pipedStream = stream;
    }

    // void closeOutputStream() {
    //     if(this.pipedStream !is null)
    //         this.pipedStream.getOutputStream().close();
    // }

    OutputStream getOutputStream() {
        return this.pipedStream.getOutputStream();
    }

    Object getAttachment() {
        return attachment;
    }

    void setAttachment(Object attachment) {
        this.attachment = attachment;
    }

    // string getStringBody(string charset) {
    //     // FIXME: Needing refactor or cleanup -@zhangxueping at 2019-10-15T09:49:13+08:00
    //     // 
    //     if (_stringBody is null) {
    //         Appender!string buffer;
    //         foreach(ByteBuffer b; _requestBody) {
    //             buffer.put(cast(string)b.array);
    //         }
    //         _stringBody = buffer.data; // BufferUtils.toString(_requestBody, charset);
    //     } 
    //     return _stringBody;
    // }

    string getStringBody(string charset) {
        if (_stringBody != null) {
            return _stringBody;
        } else {
            InputStream inputStream = this.pipedStream.getInputStream();
            if (inputStream is null) {
                return null;
            } else {
                try  {
                    int size = inputStream.available();
                    version(HUNT_HTTP_DEBUG) warningf("available: %d", size);
                    byte[] buffer = new byte[size];
                    inputStream.read(buffer);
                    _stringBody = cast(string)buffer;
                    return _stringBody;
                } catch (IOException e) {
                    version(HUNT_DEBUG) warning("get string body exception: ", e.msg);
                    version(HUNT_HTTP_DEBUG) warning(e);
                    return null;
                }
            }
        }
    }

    string getStringBody() {
        return getStringBody("UTF-8");
    }

    private shared long chunkedEncodingContentLength;

    void onContent(ByteBuffer buffer) {
        // if(_contentHandler is null) {
        //     _requestBody.add(buffer);
        // } else {
        //     _contentHandler(buffer);
        // }

        version(HUNT_HTTP_DEBUG) {
            tracef("http body handler received content size -> %s", buffer.remaining());
        }

        try {
            if (isChunked()) {
                implementationMissing(false);
                // if (chunkedEncodingContentLength.addAndGet(buf.remaining()) > _options.getBodyBufferThreshold()
                //         && httpBody.pipedStream instanceof ByteArrayPipedStream) {
                //     // chunked encoding content dump to temp file
                //     IOUtils.close(httpBody.pipedStream.getOutputStream());
                //     FilePipedStream filePipedStream = new FilePipedStream(_options.getTempFilePath());
                //     IO.copy(httpBody.pipedStream.getInputStream(), filePipedStream.getOutputStream());
                //     filePipedStream.getOutputStream().write(BufferUtils.toArray(buf));
                //     httpBody.pipedStream = filePipedStream;
                // } else {
                //     httpBody.pipedStream.getOutputStream().write(BufferUtils.toArray(buf));
                // }
            } else {
                getOutputStream().write(BufferUtils.toArray(buffer));

            }
        } catch (IOException e) {
            version(HUNT_DEBUG) warning("http server receives http body exception: ", e.msg);
            version(HUNT_HTTP_DEBUG) warning(e);
        }        
    }

    void onContentComplete() {
        // if(_contentCompleteHandler !is null)
        //     _contentCompleteHandler(this);
        if(pipedStream is null || getContentLength() <=0)
            return;
            
        try {
            string mimeType = getMimeType();
            version(HUNT_HTTP_DEBUG) trace("mimeType: ", mimeType);
            getOutputStream().close();

            if ("multipart/form-data".equalsIgnoreCase(mimeType)) {
                import hunt.http.server.HttpRequestOptions;
                import hunt.http.server.GlobalSettings;

                HttpRequestOptions _options = GlobalSettings.httpServerOptions.requestOptions();
                multipartFormInputStream = new MultipartFormInputStream(
                        pipedStream.getInputStream(),
                        getContentType(),
                        _options.getMultipartOptions(),
                        _options.getTempFilePath());
            }
        } catch (IOException e) {
            version(HUNT_DEBUG) warning("http server ends receiving data exception: ", e.msg);
            version(HUNT_HTTP_DEBUG) warning(e);
        }
    }


    Part[] getParts() {
        if (multipartFormInputStream is null) 
            return null;

        try {
            return multipartFormInputStream.getParts();
        } catch (IOException e) {
            version(HUNT_DEBUG) warning("get multi part exception: ", e.msg);
            version(HUNT_HTTP_DEBUG) warning(e);
            return null;
        }
    }

    Part getPart(string name) {
        if (multipartFormInputStream is null) 
            return null;

        try {
            return multipartFormInputStream.getPart(name);
        } catch (IOException e) {
            version(HUNT_DEBUG) warning("get multi part exception: ", e.msg);
            version(HUNT_HTTP_DEBUG) warning(e);
            return null;
        }
    }    

    void onMessageComplete() {
        if(_messageCompleteHandler !is null)
            _messageCompleteHandler(this);
    }

    // HttpRequest onContent(Action1!ByteBuffer handler) {
    //     _contentHandler = handler;
    //     return this;
    // }

    // HttpRequest onContentComplete(Action1!HttpRequest handler) {
    //     _contentCompleteHandler = handler;
    //     return this;
    // }

    HttpRequest onMessageComplete(Action1!HttpRequest handler) {
        _messageCompleteHandler = handler;
        return this;
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