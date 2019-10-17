module hunt.http.server.HttpServerRequest;

import hunt.http.server.GlobalSettings;
import hunt.http.server.Http1ServerConnection;
import hunt.http.server.HttpRequestOptions;
import hunt.http.server.HttpServerResponse;
import hunt.http.server.ServerHttpHandler;

import hunt.http.codec.http.decode.HttpParser;
import hunt.http.codec.http.model;

import hunt.collection;
import hunt.Exceptions;
import hunt.Functions;
import hunt.io.Common;
import hunt.io.PipedStream;
import hunt.logging.ConsoleLogger;
import hunt.net.util.UrlEncoded;
import hunt.text.Common;
import hunt.util.Common;
import hunt.util.MimeTypeUtils;

import std.string : icmp;
import std.range;

/**
 * 
 */
class HttpServerRequest : HttpRequest {
    
    // private List!(ByteBuffer) _requestBody; 
    private string _stringBody; 
    private string _mimeType;

    private PipedStream pipedStream;
    private MultipartFormParser multipartFormInputStream;
    private UrlEncoded urlEncodedMap;
    private string charset;

    // private Action1!ByteBuffer _contentHandler;
    // private Action1!HttpServerRequest _contentCompleteHandler;
    private Action1!HttpServerRequest _messageCompleteHandler;  

    this(string method, string uri, HttpVersion ver) {
        enum string connect = HttpMethod.CONNECT.asString();
        super(method, 
            new HttpURI(icmp(method, connect) == 0 ? "http://" ~ uri : uri), 
            ver, new HttpFields());        
        // _requestBody = new ArrayList!(ByteBuffer)();

        // super(method, new HttpURI(HttpMethod.fromString(method) == HttpMethod.CONNECT ? "http://" ~ uri : uri), ver, new HttpFields());
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

        string queryString = getURI().getQuery();
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
                    version(HUNT_HTTP_DEBUG) tracef("available: %d", size);
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
                multipartFormInputStream = new MultipartFormParser(
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

    HttpServerRequest onMessageComplete(Action1!HttpServerRequest handler) {
        _messageCompleteHandler = handler;
        return this;
    }

}