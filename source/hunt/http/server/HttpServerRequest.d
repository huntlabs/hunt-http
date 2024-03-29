module hunt.http.server.HttpServerRequest;

import hunt.http.server.GlobalSettings;
import hunt.http.server.Http1ServerConnection;
import hunt.http.server.HttpRequestOptions;
import hunt.http.server.HttpServerOptions;
import hunt.http.server.HttpServerResponse;
import hunt.http.server.ServerHttpHandler;

import hunt.http.codec.http.decode.HttpParser;
import hunt.http.codec.http.decode.MultipartFormParser;
import hunt.http.codec.http.model;

import hunt.http.Cookie;
import hunt.http.HttpFields;
import hunt.http.HttpHeader;
import hunt.http.HttpMethod;
import hunt.http.HttpRequest;
import hunt.http.HttpVersion;
import hunt.http.MultipartForm;

import hunt.collection;
import hunt.concurrency.atomic;
import hunt.Exceptions;
import hunt.Functions;
import hunt.io.BufferUtils;
import hunt.stream.PipedStream;
import hunt.stream.ByteArrayInputStream;
import hunt.stream.Common;
import hunt.logging;
import hunt.net.util.HttpURI;
import hunt.net.util.UrlEncoded;
import hunt.text.Common;
import hunt.util.Common;
import hunt.util.MimeTypeUtils;

import std.algorithm;
import std.array;
import std.conv;
import std.container.array;
import std.json;
import std.string : icmp, strip;
import std.range;


/**
 * 
 */
class HttpServerRequest : HttpRequest {
    
    private string[][string] _formData;  // data buffer for form-data and x-www-form-urlencoded
    private string[string] _queryParams;
    
    private bool _isMultipart = false;
    private bool _isXFormUrlencoded = false;
    private bool _isQueryParamsSet = false;

    private string _stringBody; 
    private string _mimeType;
    private HttpServerOptions _options;

    private Cookie[] _cookies;
    private PipedStream _pipedStream;
    private MultipartFormParser _multipartFormParser;
    private UrlEncoded _urlEncodedMap;

    private Action1!HttpServerRequest _messageCompleteHandler;
    private Action1!HttpServerRequest _contentCompleteHandler;  

    this(string method, string uri, HttpVersion ver, HttpServerOptions options) {
        enum string connect = HttpMethod.CONNECT.asString();
        _options = options;

        super(method, new HttpURI(icmp(method, connect) == 0 ? "http://" ~ uri : uri), 
            ver, new HttpFields());   
        // _originalPath = uri;  
        _originalPath = getURI().getPath();
        // super(method, new HttpURI(HttpMethod.fromString(method) == HttpMethod.CONNECT ? "http://" ~ uri : uri), ver, new HttpFields());
    }

    @property string host() {
        return header(HttpHeader.HOST);
    }
    
    string getParameter(string name) {
        decodeUrl();
        return _urlEncodedMap.getString(name);
    }

    List!(string) getParameterValues(string name) {
        decodeUrl();
        return _urlEncodedMap.getValues(name);
    }

    Map!(string, List!(string)) getParameterMap() {
        decodeUrl();
        return _urlEncodedMap;
    }

    string getMimeType() {
        if(_mimeType is null) {
            _mimeType = MimeTypeUtils.getContentTypeMIMEType(getContentType());
        }

        return _mimeType;
    }
    
    private void decodeUrl() {
        if(_urlEncodedMap !is null)
            return;

        _urlEncodedMap = new UrlEncoded();

        string queryString = getURI().getQuery();
        if (!queryString.empty()) {
            _urlEncodedMap.decode(queryString);
        }

        // if ("application/x-www-form-urlencoded".equalsIgnoreCase(getMimeType())) {
        //     string bodyString = getStringBody(_options.requestOptions.getCharset());
        //     _urlEncodedMap.decode(bodyString);
        // }
    }

    private OutputStream getOutputStream() {
        return this._pipedStream.getOutputStream();
    }

    string getStringBody(string charset) {
        if (_stringBody !is null) {
            return _stringBody;
        } else {
            if (_pipedStream is null) // no content
                return null;

            InputStream inputStream = this._pipedStream.getInputStream();
            scope(exit) 
                inputStream.close();

            try  {
                // inputStream.position(0); // The InputStream may be read, so reset it before reading it again.
                int size = inputStream.available();
                version(HUNT_HTTP_DEBUG) tracef("available: %d", size);
                // TODO: Tasks pending completion -@zhangxueping at 2019-10-23T15:40:56+08:00
                // encoding convertion: to UTF-8
                
                // skip the read for better performance
                byte[] buffer;
                ByteArrayInputStream arrayStream = cast(ByteArrayInputStream)inputStream;
                if(arrayStream is null) {
                    buffer = new byte[size];
                    int number = inputStream.read(buffer);
                    if(number == -1) {
                        version(HUNT_DEBUG) warning("no data for read");
                    }
                } else {
                    buffer = arrayStream.getRawBuffer();
                }
                _stringBody = cast(string)buffer;
                return _stringBody;
            } catch (IOException e) {
                version(HUNT_DEBUG) warning("Get an exception for string body: ", e.msg);
                version(HUNT_HTTP_DEBUG) warning(e);
                return null;
            }
        }
    }

    string getStringBody() {
        return getStringBody("UTF-8");
    }

    package(hunt.http) void onHeaderComplete() {
        // _options = options;
        auto options = _options.requestOptions;
        if (isChunked()) {
            this._pipedStream = new ByteArrayPipedStream(4 * 1024);
        } else {
            long contentLength = getContentLength();
           
            if (contentLength > options.getBodyBufferThreshold()) {
                this._pipedStream = new FilePipedStream(options.getTempFilePath());
            } else if(contentLength > 0) {
                this._pipedStream = new ByteArrayPipedStream(cast(int) contentLength);
            }
        }
    }

    private shared long chunkedEncodingContentLength;

    package(hunt.http) void onContent(ByteBuffer buffer) {
        version(HUNT_HTTP_DEBUG) {
            tracef("received content size -> %s bytes", buffer.remaining());
        }

        try {
            OutputStream outStream = getOutputStream();
            if (isChunked()) {
                auto options = _options.requestOptions;
                long length = AtomicHelper.increment(chunkedEncodingContentLength, buffer.remaining());
                ByteArrayPipedStream bytesStream = cast(ByteArrayPipedStream)_pipedStream;

                // switch PipedStream from ByteArrayPipedStream to FilePipedStream.
                if (length > options.getBodyBufferThreshold() && bytesStream !is null) {
                    // FIXME: Needing refactor or cleanup -@zhangxueping at 2019-10-17T23:05:10+08:00
                    // better performance.
                    
                    version(HUNT_HTTP_DEBUG) {
                        warningf("dump to temp file, ContentLength:%d, BufferThreshold: %d, file: %s", 
                            length,
                            options.getBodyBufferThreshold(), 
                            options.getTempFilePath());
                    }

                    // chunked encoding content dump to temp file
                    _pipedStream.getOutputStream().close();
                    FilePipedStream filePipedStream = new FilePipedStream(options.getTempFilePath());
                    byte[] bufferedBytes = bytesStream.getOutputStream().toByteArray(false);
                    OutputStream fileOutStream = filePipedStream.getOutputStream();
                    fileOutStream.write(bufferedBytes);
                    fileOutStream.write(BufferUtils.toArray(buffer, false));
                    _pipedStream = filePipedStream;
                } else {
                    outStream.write(BufferUtils.toArray(buffer, false));
                }
            } else {
                outStream.write(BufferUtils.toArray(buffer, false));
            }
        } catch (IOException e) {
            version(HUNT_DEBUG) warning("http server receives http body exception: ", e.msg);
            version(HUNT_HTTP_DEBUG) warning(e);
        }        
    }

    package(hunt.http) void onContentComplete() {
        if(_pipedStream is null || (getContentLength() <=0 && !isChunked()) )
            return;
            
        try {
            string mimeType = getMimeType();
            version(HUNT_HTTP_DEBUG) trace("mimeType: ", mimeType);
            getOutputStream().close();

            if ("multipart/form-data".equalsIgnoreCase(mimeType)) {
                _multipartFormParser = new MultipartFormParser(
                        _pipedStream.getInputStream(),
                        getContentType(),
                        GlobalSettings.getMultipartOptions(_options.requestOptions),
                        _options.requestOptions.getTempFilePath());
            } else if("application/x-www-form-urlencoded".equalsIgnoreCase(mimeType)) {
                _isXFormUrlencoded = true;
            }

            if(_contentCompleteHandler !is null) {
                _contentCompleteHandler(this);
            }
        } catch (IOException e) {
            version(HUNT_DEBUG) warning("http server ends receiving data exception: ", e.msg);
            version(HUNT_HTTP_DEBUG) warning(e);
        }
    } 

    package(hunt.http) void onMessageComplete() {
        if(_messageCompleteHandler !is null)
            _messageCompleteHandler(this);
    }

    // HttpRequest onContent(Action1!ByteBuffer handler) {
    //     _contentHandler = handler;
    //     return this;
    // }

    HttpRequest onContentComplete(Action1!HttpServerRequest handler) {
        _contentCompleteHandler = handler;
        return this;
    }

    HttpServerRequest onMessageComplete(Action1!HttpServerRequest handler) {
        _messageCompleteHandler = handler;
        return this;
    }

    
    HttpServerRequest onBadMessage(Action1!HttpServerRequest handler) {
        _messageCompleteHandler = handler;
        return this;
    }
    

    Cookie[] getCookies() {        
        if (_cookies is null) {

            Array!(Cookie) list;
            foreach (string v; getFields().getValuesList(HttpHeader.COOKIE)) {
                if (v.empty)
                    continue;
                foreach (Cookie c; parseCookie(v))
                    list.insertBack(c);
            }
            _cookies = list.array();
            // _cookies = getFields().getValuesList(HttpHeader.COOKIE)
			// 		.map!(parseSetCookie).array;
        }
		
		return _cookies;
    }

    bool isMultipartForm() {
        return _multipartFormParser !is null;
    }

    bool isXFormUrlencoded() {
        return _isXFormUrlencoded;
    }

    Part[] getParts() {
        if (_multipartFormParser is null) {
            throw new RuntimeException("The request is not a multipart form.");
        }

        // try {
            return _multipartFormParser.getParts();
        // } catch (IOException e) {
        //     version(HUNT_DEBUG) warning("get multi part exception: ", e.msg);
        //     version(HUNT_HTTP_DEBUG) warning(e);
        //     return null;
        // }
    }

    Part getPart(string name) {
        if (_multipartFormParser is null) {
            throw new RuntimeException("The reqest is not a multipart form.");
            // return null;
        }

        // try {
            return _multipartFormParser.getPart(name);
        // } catch (IOException e) {
        //     version(HUNT_DEBUG) warning("get multi part exception: ", e.msg);
        //     version(HUNT_HTTP_DEBUG) warning(e);
        //     return null;
        // }
    } 
    

// dfmtoff Some Helpers

    import std.string;

    @property string originalPath() {
        return _originalPath;
    }
    private string _originalPath;

    @property string path() {
        return getURI().getPath();
    }

    @property void path(string value) {
        getURI().setPath(value);
    }

    @property string decodedPath() {
        return getURI().getDecodedPath();
    }

    string opDispatch(string key)() {
        version(HUNT_HTTP_DEBUG) {
            tracef("Get the query parameter: %s", key);
        }
        return query(key);
    }

    /**
     * Retrieve a query string item from the request.
     *
     * @param  string  key
     * @param  string|array|null  default
     * @return string|array
     */
    string query(string key, string defaults = null) {
        return queries().get(key, defaults);
    }

    /// get a query
    T get(T = string)(string key, T v = T.init) {
        version(HUNT_HTTP_DEBUG) {
            tracef("key: %s, value: %s", key, v);
        }

        auto tmp = queries();
        if (tmp is null) {
            return v;
        }
        
        static if(is(T == string)) {
            if(v is null) v = "";
        }

        auto _v = tmp.get(key, "");
        version(HUNT_HTTP_DEBUG) {
            tracef("key: %s, value: %s, target: %s, default: %s", key, _v, T.stringof, v);
        }

        if (_v.length) {
            try {
                return to!T(_v);
            } catch(Exception ex) {
                string msg = format("Failed converting from <%s> to %s", _v, T.stringof);
                warning(msg);
                // warning(ex);
                //throw new Exception(msg);
                return v;
            }
        }
        
        return v;
    }

    /**
     * Retrieve a request payload item from the request.
     *
     * @param  string  key
     * @param  string|array|null  default
     *
     * @return string|array
     */
    T post(T = string)(string key, T v = T.init) {

        string[][string] form = formData();
        
        if(key in form) {
            string[] _v = form[key];
            if (_v.length > 0) {
                static if(is(T == string))
                    v = _v[0];
                else {
                    v = to!T(_v[0]);
                }
            } 
        }                 
            
        return v;
    }

    T[] posts(T = string)(string key, T[] v = null) {
        string[][string] form = formData();
        if (form is null)
            return v;
            
        if(key in form) {
            string[] _v = form[key];
            if (_v.length > 0) {
                static if(is(T == string))
                    v = _v[];
                else {
                    v = new T[_v.length];
                    for(size i =0; i<v.length; i++) {
                        v[i] = to!T(_v[i]);
                    }
                }
            } 
        } 

        return v;
    }

    // get queries
    @property ref string[string] queries() {
        if (!_isQueryParamsSet) {
            MultiMap!string map = getURI().decodeQuery();
            foreach (string key, List!(string) values; map) {
                version(HUNT_DEBUG) {
                    infof("query parameter: key=%s, values=%s", key, values[0]);
                }
                if(values is null || values.size()<1) {
                    _queryParams[key] = ""; 
                } else {
                    _queryParams[key] = values[0];
                }
            }
            _isQueryParamsSet = true;
        }
        return _queryParams;
    }

    void putQueryParameter(string key, string value) {
        version(HUNT_HTTP_DEBUG) infof("query parameter: key=%s, values=%s", key, value);
        _queryParams[key] = value;
    }

    /**
     * Replace the input for the current request.
     *
     * @param  array input
     * @return Request
     */
    void replace(string[string] input) {
        if (isContained(this.getMethod(), ["GET", "HEAD"]))
            _queryParams = input;
        else {
            foreach(string k, string v; input) {
                _formData[k] ~= v;
            }
        }
    }

    private static bool isContained(string source, string[] keys) {
        foreach (string k; keys) {
            if (canFind(source, k))
                return true;
        }

        return false;
    }
    
    T bindForm(T)() if(is(T == class) || is(T == struct)) {
        if(getMethod() != HttpMethod.POST.asString() && 
            getMethod() != HttpMethod.PUT.asString()) {
            version(HUNT_DEBUG) {
                warningf("The required method is POST or PUT. Here is yours: %s", getMethod());
            }
            return T.init;
        }

        import hunt.serialization.JsonSerializer;

        JSONValue jv;
        string[][string] forms = formData();
        if(forms is null) {
            static if(is(T == class)) {
                return new T();
            } else {
                return T.init;
            }
        }

        foreach(string k, string[] values; forms) {
            if(values.length > 1) {
                jv[k] = JSONValue(values);
            } else if(values.length == 1) {
                jv[k] = JSONValue(values[0]);
            } else {
                warningf("null value for %s in form data: ", k);
            }
        }
        
        import hunt.serialization.Common;
        return JsonSerializer.toObject!(T, SerializationOptions.Default.canThrow(false))(jv);
    }

    deprecated("Using formData instead.")
    alias xFormData = formData;

    @property string[][string] formData() {
        if (_formData !is null) 
            return _formData;

        if(_isXFormUrlencoded) {
            UrlEncoded map = new UrlEncoded(UrlEncodeStyle.HtmlForm);
            map.decode(getStringBody());
            foreach (string key; map.byKey()) {
                foreach(string v; map.getValues(key)) {
                    key = key.strip();
                    _formData[key] ~= v.strip();
                }
            }
        } else if (isMultipartForm()) {
            foreach (Part part; getParts()) {
                MultipartForm multipart = cast(MultipartForm) part;

                string contentType = multipart.getContentType();
                string submittedFileName = multipart.getSubmittedFileName();
                string key = multipart.getName();
                if (submittedFileName.empty) {
                    string content = cast(string)multipart.getBytes();
                    content = content.strip();
                    version (HUNT_HTTP_DEBUG) {
                        if(content.length > 128) {
                            content = content[0..128] ~ "...";
                        } 

                        tracef("File: key=%s, fileName=%s, actualFile=%s, ContentType=%s, content=%s",
                                key, submittedFileName, multipart.getFile(), multipart.getContentType(),
                                content); 
                    } 

                    _formData[key] ~= content;
                } 
            }            
        }

        return _formData;
    }

    /**
     * Retrieve a cookie from the request.
     *
     * @param  string  key
     * @param  string|array|null  default
     * @return string|array
     */
    string cookie(string key, string defaultValue = null) {
        // return cookieManager.get(key, defaultValue);
        foreach (Cookie c; getCookies()) {
            if (c.getName == key)
                return c.getValue();
        }

        return defaultValue;
    }

    /**
     * Retrieve  users' own preferred language.
     */
    string locale() {
        string l;
        l = cookie("Content-Language");
        if(l is null)
            l = _options.requestOptions.defaultLanguage();

        return toLower(l);
    }
    

// dfmton


}