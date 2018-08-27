module hunt.http.server.http.router.handler.HTTPBodyHandler;

import hunt.http.util.UrlEncoded;
import hunt.http.codec.http.model;
import hunt.http.server.http.SimpleRequest;
import hunt.http.server.http.router.handler.Handler;
import hunt.http.server.http.router.RoutingContext;
import hunt.http.server.http.router.impl.RoutingContextImpl;
// import hunt.http.utils.io.ByteArrayPipedStream;
// import hunt.http.utils.io.FilePipedStream;

import hunt.container;
import hunt.io;

import hunt.util.exception;
import hunt.util.string;

import hunt.logging;
import std.array;

/**
 * 
 */
class HTTPBodyHandler : Handler {

    private HTTPBodyConfiguration configuration;

    this() {
        this(new HTTPBodyConfiguration());
    }

    this(HTTPBodyConfiguration configuration) {
        this.configuration = configuration;
    }

    HTTPBodyConfiguration getConfiguration() {
        return configuration;
    }

    void setConfiguration(HTTPBodyConfiguration configuration) {
        this.configuration = configuration;
    }

    override void handle(RoutingContext context) {

        RoutingContextImpl ctx = cast(RoutingContextImpl) context;
        SimpleRequest request = ctx.getRequest();
        HTTPBodyHandlerSPIImpl httpBodyHandlerSPI = new HTTPBodyHandlerSPIImpl();
        httpBodyHandlerSPI.urlEncodedMap = new UrlEncoded();
        httpBodyHandlerSPI.charset = configuration.getCharset();
        ctx.setHTTPBodyHandlerSPI(httpBodyHandlerSPI);

        string queryString = request.getURI().getQuery();
        if (!queryString.empty()) {
            httpBodyHandlerSPI.urlEncodedMap.decode(queryString);
        }

        if (ctx.isAsynchronousRead()) { // receive content event has been listened
            ctx.next();
            return;
        }

        if (isChunked(request)) {
            // httpBodyHandlerSPI.pipedStream = new ByteArrayPipedStream(4 * 1024);
            implementationMissing(false);
        } else {
            long contentLength = request.getContentLength();
            if (contentLength <= 0) { // no content
                ctx.next();
                return;
            } else {
                if (contentLength > configuration.getBodyBufferThreshold()) {
                    // httpBodyHandlerSPI.pipedStream = new FilePipedStream(configuration.getTempFilePath());
                    implementationMissing(false);
                } else {
                    httpBodyHandlerSPI.pipedStream = new ByteArrayPipedStream(cast(int) contentLength);
                }
            }
        }

        long chunkedEncodingContentLength;
        ctx.onContent( (ByteBuffer buf) {
            version(HuntDebugMode) {
                tracef("http body handler received content size -> %s", buf.remaining());
            }

            try {
                if (isChunked(request)) {

                    implementationMissing(false);
                    // if (chunkedEncodingContentLength.addAndGet(buf.remaining()) > configuration.getBodyBufferThreshold()
                    //         && httpBodyHandlerSPI.pipedStream instanceof ByteArrayPipedStream) {
                    //     // chunked encoding content dump to temp file
                    //     IO.close(httpBodyHandlerSPI.pipedStream.getOutputStream());
                    //     FilePipedStream filePipedStream = new FilePipedStream(configuration.getTempFilePath());
                    //     IO.copy(httpBodyHandlerSPI.pipedStream.getInputStream(), filePipedStream.getOutputStream());
                    //     filePipedStream.getOutputStream().write(BufferUtils.toArray(buf));
                    //     httpBodyHandlerSPI.pipedStream = filePipedStream;
                    // } else {
                    //     httpBodyHandlerSPI.pipedStream.getOutputStream().write(BufferUtils.toArray(buf));
                    // }
                } else {
                    httpBodyHandlerSPI.pipedStream.getOutputStream().write(BufferUtils.toArray(buf));
                }
            } catch (IOException e) {
                errorf("http server receives http body exception", e);
            }
        }).onContentComplete( (SimpleRequest req) {
            try {
                string contentType = MimeTypes.getContentTypeMIMEType(request.getFields().get(HttpHeader.CONTENT_TYPE));
                httpBodyHandlerSPI.pipedStream.getOutputStream().close();

                if ("application/x-www-form-urlencoded".equalsIgnoreCase(contentType)) {
                    implementationMissing(false);
                        // InputStream inputStream = httpBodyHandlerSPI.pipedStream.getInputStream();
                        // httpBodyHandlerSPI.urlEncodedMap.decode(IO.toString(inputStream, configuration.getCharset()),
                        //         Charset.forName(configuration.getCharset()));
                } else if ("multipart/form-data".equalsIgnoreCase(contentType)) {

                    implementationMissing(false);
                    // httpBodyHandlerSPI.multiPartFormInputStream = new MultiPartFormInputStream(
                    //         httpBodyHandlerSPI.getInputStream(),
                    //         request.getFields().get(HttpHeader.CONTENT_TYPE),
                    //         configuration.getMultipartConfigElement(),
                    //         new File(configuration.getTempFilePath()));
                }
            } catch (IOException e) {
                errorf("http server ends receiving data exception", e);
            }
        }).onMessageComplete((SimpleRequest req) { ctx.next(); });
    }

    bool isChunked(SimpleRequest request) {
        string transferEncoding = request.getFields().get(HttpHeader.TRANSFER_ENCODING);
        return HttpHeaderValue.CHUNKED.asString() == transferEncoding
                || (request.getHttpVersion() == HttpVersion.HTTP_2 && request.getContentLength() < 0);
    }
}


/**
 * 
 */
interface HTTPBodyHandlerSPI {

    string getParameter(string name);

    List!(string) getParameterValues(string name);

    Map!(string, List!(string)) getParameterMap();

    // Collection<Part> getParts();

    // Part getPart(string name);

    InputStream getInputStream();

    // BufferedReader getBufferedReader();

    string getStringBody(string charset);

    string getStringBody();

    // <T> T getJsonBody(Class<T> clazz);

    // <T> T getJsonBody(GenericTypeReference<T> typeReference);

    // JsonObject getJsonObjectBody();

    // JsonArray getJsonArrayBody();

}

/*
 * 
 */
class HTTPBodyHandlerSPIImpl : HTTPBodyHandlerSPI {

    PipedStream pipedStream;
    // MultiPartFormInputStream multiPartFormInputStream;
    UrlEncoded urlEncodedMap;
    string charset;
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
                    ByteArrayInputStream stream = cast(ByteArrayInputStream)inputStream;
                    // stringBody = IO.toString(inputStream, Charset.forName(charset));
                    stringBody = cast(string)stream.getRawBuffer();
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

/**
 * 
 */
class HTTPBodyConfiguration {

    private int bodyBufferThreshold = 512 * 1024;
    private int maxRequestSize = 64 * 1024 * 1024;
    private int maxFileSize = 64 * 1024 * 1024;
    private string tempFilePath = "./"; //System.getProperty("java.io.tmpdir");
    private string charset = "UTF-8";
    // private MultipartConfigElement multipartConfigElement = new MultipartConfigElement(tempFilePath, maxFileSize, maxRequestSize, bodyBufferThreshold);

    int getBodyBufferThreshold() {
        return bodyBufferThreshold;
    }

    void setBodyBufferThreshold(int bodyBufferThreshold) {
        this.bodyBufferThreshold = bodyBufferThreshold;
    }

    int getMaxRequestSize() {
        return maxRequestSize;
    }

    void setMaxRequestSize(int maxRequestSize) {
        this.maxRequestSize = maxRequestSize;
    }

    string getTempFilePath() {
        return tempFilePath;
    }

    void setTempFilePath(string tempFilePath) {
        this.tempFilePath = tempFilePath;
    }

    string getCharset() {
        return charset;
    }

    void setCharset(string charset) {
        this.charset = charset;
    }

    // MultipartConfigElement getMultipartConfigElement() {
    //     return multipartConfigElement;
    // }

    // void setMultipartConfigElement(MultipartConfigElement multipartConfigElement) {
    //     this.multipartConfigElement = multipartConfigElement;
    // }
}