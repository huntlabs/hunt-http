module hunt.http.server.HttpServerRequest;

import hunt.http.server.GlobalSettings;
import hunt.http.server.Http1ServerConnection;
import hunt.http.server.HttpRequestOptions;
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
import hunt.io.Common;
import hunt.io.PipedStream;
import hunt.io.ByteArrayInputStream;
import hunt.logging.ConsoleLogger;
import hunt.net.util.HttpURI;
import hunt.net.util.UrlEncoded;
import hunt.text.Common;
import hunt.util.Common;
import hunt.util.MimeTypeUtils;

import std.array;
import std.container.array;
import std.string : icmp;
import std.range;

/**
 * 
 */
class HttpServerRequest : HttpRequest {
    
    private string _stringBody; 
    private string _mimeType;
    private HttpRequestOptions _options;

    private Cookie[] _cookies;
    private PipedStream _pipedStream;
    private MultipartFormParser _multipartFormParser;
    private UrlEncoded _urlEncodedMap;

    // private Action1!ByteBuffer _contentHandler;
    // private Action1!HttpServerRequest _contentCompleteHandler;
    private Action1!HttpServerRequest _messageCompleteHandler;  

    this(string method, string uri, HttpVersion ver) {
        enum string connect = HttpMethod.CONNECT.asString();
        super(method, 
            new HttpURI(icmp(method, connect) == 0 ? "http://" ~ uri : uri), 
            ver, new HttpFields());        

        // super(method, new HttpURI(HttpMethod.fromString(method) == HttpMethod.CONNECT ? "http://" ~ uri : uri), ver, new HttpFields());
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

        if ("application/x-www-form-urlencoded".equalsIgnoreCase(getMimeType())) {
            // HttpRequestOptions _options = GlobalSettings.httpServerOptions.requestOptions();
            string bodyString = getStringBody(_options.getCharset());
            _urlEncodedMap.decode(bodyString);
        }
    }

    // void setPipedStream(PipedStream stream) {
    //     this._pipedStream = stream;
    // }

    // void closeOutputStream() {
    //     if(this._pipedStream !is null)
    //         this._pipedStream.getOutputStream().close();
    // }

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
                        version(HUNT_DEBUG) warning("no data read");
                    }
                } else {
                    buffer = arrayStream.getRawBuffer();
                }
                _stringBody = cast(string)buffer;
                return _stringBody;
            } catch (IOException e) {
                version(HUNT_DEBUG) warning("get string body exception: ", e.msg);
                version(HUNT_HTTP_DEBUG) warning(e);
                return null;
            }
        }
    }

    string getStringBody() {
        return getStringBody("UTF-8");
    }

    package(hunt.http) void onHeaderComplete(HttpRequestOptions options) {
        _options = options;
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
                long length = AtomicHelper.increment(chunkedEncodingContentLength, buffer.remaining());
                ByteArrayPipedStream bytesStream = cast(ByteArrayPipedStream)_pipedStream;

                // switch PipedStream from ByteArrayPipedStream to FilePipedStream.
                if (length > _options.getBodyBufferThreshold() && bytesStream !is null) {
                    // FIXME: Needing refactor or cleanup -@zhangxueping at 2019-10-17T23:05:10+08:00
                    // better performance.
                    
                    version(HUNT_HTTP_DEBUG) {
                        warningf("dump to temp file, ContentLength:%d, BufferThreshold: %d, file: %s", 
                            length,
                            _options.getBodyBufferThreshold(), 
                            _options.getTempFilePath());
                    }

                    // chunked encoding content dump to temp file
                    _pipedStream.getOutputStream().close();
                    FilePipedStream filePipedStream = new FilePipedStream(_options.getTempFilePath());
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
                import hunt.http.server.HttpRequestOptions;
                import hunt.http.server.GlobalSettings;

                HttpRequestOptions _options = GlobalSettings.httpServerOptions.requestOptions();
                _multipartFormParser = new MultipartFormParser(
                        _pipedStream.getInputStream(),
                        getContentType(),
                        GlobalSettings.getMultipartOptions(_options),
                        _options.getTempFilePath());
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

    // HttpRequest onContentComplete(Action1!HttpRequest handler) {
    //     _contentCompleteHandler = handler;
    //     return this;
    // }

    package(hunt.http) HttpServerRequest onMessageComplete(Action1!HttpServerRequest handler) {
        _messageCompleteHandler = handler;
        return this;
    }

    Cookie[] getCookies() {
        if (_cookies is null) {
			Array!(Cookie) list;
			foreach(string v; getFields().getValuesList(HttpHeader.COOKIE)) {
				if(v.empty) continue;
				foreach(Cookie c; CookieParser.parseCookie(v))
					list.insertBack(c);
			}
			_cookies = list.array();
        }
        return _cookies;
    }


    Part[] getParts() {
        if (_multipartFormParser is null) 
            return null;

        // try {
            return _multipartFormParser.getParts();
        // } catch (IOException e) {
        //     version(HUNT_DEBUG) warning("get multi part exception: ", e.msg);
        //     version(HUNT_HTTP_DEBUG) warning(e);
        //     return null;
        // }
    }

    Part getPart(string name) {
        if (_multipartFormParser is null) 
            return null;

        // try {
            return _multipartFormParser.getPart(name);
        // } catch (IOException e) {
        //     version(HUNT_DEBUG) warning("get multi part exception: ", e.msg);
        //     version(HUNT_HTTP_DEBUG) warning(e);
        //     return null;
        // }
    }   

}