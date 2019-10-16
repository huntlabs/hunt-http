module hunt.http.router.handler.HttpBodyHandler;

import hunt.http.router.handler.HttpBodyOptions;
import hunt.http.router.HttpRequestBody;
import hunt.http.router.RoutingHandler;
import hunt.http.router.RoutingContext;
import hunt.http.router.impl.RoutingContextImpl;
// import hunt.http.utils.io.ByteArrayPipedStream;
// import hunt.http.utils.io.FilePipedStream;
import hunt.http.codec.http.model;

import hunt.collection;
import hunt.io;
import hunt.Exceptions;
import hunt.logging;
import hunt.net.util.UrlEncoded;
import hunt.text;
import hunt.util.MimeTypeUtils;

import std.array;

/**
 * 
 */
class HttpBodyHandler : IRoutingHandler {

    private HttpBodyOptions _options;

    this() {
        this(new HttpBodyOptions());
    }

    this(HttpBodyOptions options) {
        this._options = options;
    }

    HttpBodyOptions getConfiguration() {
        return _options;
    }

    void setConfiguration(HttpBodyOptions options) {
        this._options = options;
    }

    override void handle(RoutingContext context) {
        // RoutingContextImpl ctx = cast(RoutingContextImpl) context;
        RoutingContext ctx =  context;
        HttpRequest request = ctx.getRequest();
        HttpRequestBodyImpl httpBody = new HttpRequestBodyImpl();
        httpBody.urlEncodedMap = new UrlEncoded();
        httpBody.charset = _options.getCharset();
        ctx.setHttpBody(httpBody);

        string queryString = request.getURI().getQuery();
        if (!queryString.empty()) {
            httpBody.urlEncodedMap.decode(queryString);
        }

        // FIXME: Needing refactor or cleanup -@zhangxueping at 2019-10-15T09:50:01+08:00
        // 
        if (ctx.isAsynchronousRead()) { // receive content event has been listened
            ctx.next();
            return;
        }

        if (isChunked(request)) {
            httpBody.pipedStream = new ByteArrayPipedStream(4 * 1024);
        } else {
            long contentLength = request.getContentLength();
            if (contentLength <= 0) { // no content
                ctx.next();
                return;
            } else {
                if (contentLength > _options.getBodyBufferThreshold()) {
                    httpBody.pipedStream = new FilePipedStream(_options.getTempFilePath());
                } else {
                    httpBody.pipedStream = new ByteArrayPipedStream(cast(int) contentLength);
                }
            }
        }

        long chunkedEncodingContentLength;
        ctx.onContent( (ByteBuffer buf) {
            version(HUNT_HTTP_DEBUG) {
                tracef("http body handler received content size -> %s", buf.remaining());
            }

            try {
                if (isChunked(request)) {

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
                    httpBody.pipedStream.getOutputStream().write(BufferUtils.toArray(buf));
                }
            } catch (IOException e) {
                errorf("http server receives http body exception", e);
            }
        }).onContentComplete( (HttpRequest req) {
            try {
                string contentType = MimeTypeUtils.getContentTypeMIMEType(request.getFields().get(HttpHeader.CONTENT_TYPE));
                httpBody.pipedStream.getOutputStream().close();

                if ("application/x-www-form-urlencoded".equalsIgnoreCase(contentType)) {
                    implementationMissing(false);
                        // InputStream inputStream = httpBody.pipedStream.getInputStream();
                        // httpBody.urlEncodedMap.decode(IO.toString(inputStream, _options.getCharset()),
                        //         Charset.forName(_options.getCharset()));
                } else if ("multipart/form-data".equalsIgnoreCase(contentType)) {

                    implementationMissing(false);
                    // httpBody.multiPartFormInputStream = new MultiPartFormInputStream(
                    //         httpBody.getInputStream(),
                    //         request.getFields().get(HttpHeader.CONTENT_TYPE),
                    //         _options.getMultipartConfigElement(),
                    //         new File(_options.getTempFilePath()));
                }
            } catch (IOException e) {
                errorf("http server ends receiving data exception", e);
            }
        }).onMessageComplete((HttpRequest req) { ctx.next(); });
    }

    bool isChunked(HttpRequest request) {
        string transferEncoding = request.getFields().get(HttpHeader.TRANSFER_ENCODING);
        return HttpHeaderValue.CHUNKED.asString() == transferEncoding
                || (request.getHttpVersion() == HttpVersion.HTTP_2 && request.getContentLength() < 0);
    }
}


/*
 * 
 */
class HttpRequestBodyImpl : HttpRequestBody {

    private PipedStream pipedStream;
    // MultiPartFormInputStream multiPartFormInputStream;
    private UrlEncoded urlEncodedMap;
    private string charset;
    // private BufferedReader bufferedReader;
    private string stringBody;


    override
    string getParameter(string name) {
        return urlEncodedMap.getString(name);
    }

    override
    List!(string) getParameterValues(string name) {
        return urlEncodedMap.getValues(name);
    }

    override
    Map!(string, List!(string)) getParameterMap() {
        return urlEncodedMap;
    }

    // override
    // Collection<Part> getParts() {
    //     if (multiPartFormInputStream == null) {
    //         return null;
    //     } else {
    //         try {
    //             return multiPartFormInputStream.getParts();
    //         } catch (IOException e) {
    //             errorf("get multi part exception", e);
    //             return null;
    //         }
    //     }
    // }

    // override
    // Part getPart(string name) {
    //     if (multiPartFormInputStream == null) {
    //         return null;
    //     } else {
    //         try {
    //             return multiPartFormInputStream.getPart(name);
    //         } catch (IOException e) {
    //             errorf("get multi part exception", e);
    //             return null;
    //         }
    //     }
    // }

    InputStream getInputStream() {
        if (pipedStream is null) {
            return null;
        } else {
            try {
                return pipedStream.getInputStream();
            } catch (IOException e) {
                errorf("get input stream exception", e);
                return null;
            }
        }
    }

    // override
    // BufferedReader getBufferedReader() {
    //     if (bufferedReader != null) {
    //         return bufferedReader;
    //     } else {
    //         if (pipedStream == null) {
    //             return null;
    //         } else {
    //             try {
    //                 bufferedReader = new BufferedReader(new InputStreamReader(pipedStream.getInputStream()));
    //                 return bufferedReader;
    //             } catch (IOException e) {
    //                 errorf("get buffered reader exception", e);
    //                 return null;
    //             }
    //         }
    //     }
    // }

    override
    string getStringBody(string charset) {
        if (stringBody != null) {
            return stringBody;
        } else {
            InputStream inputStream = getInputStream();
            if (inputStream is null) {
                return null;
            } else {
                try  {
                    // stringBody = IO.toString(inputStream, Charset.forName(charset));
                    int size = inputStream.available();
                    warningf("available: %d", size);
                    byte[] buffer = new byte[size];
                    inputStream.read(buffer);
                    stringBody = cast(string)buffer;
                    return stringBody;
                } catch (IOException e) {
                    errorf("get string body exception", e);
                    return null;
                }
            }
        }
    }

    override
    string getStringBody() {
        return getStringBody(charset);
    }

    // override
    // <T> T getJsonBody(Class<T> clazz) {
    //     return Json.toObject(getStringBody(), clazz);
    // }

    // override
    // <T> T getJsonBody(GenericTypeReference<T> typeReference) {
    //     return Json.toObject(getStringBody(), typeReference);
    // }

    // override
    // JsonObject getJsonObjectBody() {
    //     return Json.toJsonObject(getStringBody());
    // }

    // override
    // JsonArray getJsonArrayBody() {
    //     return Json.toJsonArray(getStringBody());
    // }

}
