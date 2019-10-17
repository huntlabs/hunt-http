module hunt.http.router.handler.HttpBodyHandler;

import hunt.http.router.HttpServerRequest;
import hunt.http.router.RoutingHandler;
import hunt.http.router.RoutingContext;
import hunt.http.router.impl.RoutingContextImpl;
// import hunt.http.utils.io.ByteArrayPipedStream;
// import hunt.http.utils.io.FilePipedStream;
import hunt.http.codec.http.model;

import hunt.http.server.HttpRequestOptions;

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

    private HttpRequestOptions _options;

    this() {
        this(new HttpRequestOptions());
    }

    this(HttpRequestOptions options) {
        this._options = options;
    }

    HttpRequestOptions getConfiguration() {
        return _options;
    }

    void setConfiguration(HttpRequestOptions options) {
        this._options = options;
    }

    override void handle(RoutingContext context) {
        HttpRequest request = context.getRequest();
        // HttpServerRequestImpl httpBody = new HttpServerRequestImpl();
        // httpBody.urlEncodedMap = new UrlEncoded();
        // httpBody.charset = _options.getCharset();
        // context.setHttpBody(httpBody);

        // string queryString = request.getURI().getQuery();
        // if (!queryString.empty()) {
        //     httpBody.urlEncodedMap.decode(queryString);
        // }

        if (context.isAsynchronousRead()) { // receive content event has been listened
            context.next();
            return;
        }

        if (request.isChunked()) {
            request.setPipedStream(new ByteArrayPipedStream(4 * 1024));
        } else {
            long contentLength = request.getContentLength();
            if (contentLength <= 0) { // no content
                context.next();
                return;
            } else {
                if (contentLength > _options.getBodyBufferThreshold()) {
                    request.setPipedStream(new FilePipedStream(_options.getTempFilePath()));
                } else {
                    request.setPipedStream(new ByteArrayPipedStream(cast(int) contentLength));
                }
            }
        }

        context.onMessageComplete((HttpRequest req) { context.next(); });
    }
}


// /*
//  * 
//  */
// class HttpServerRequestImpl : HttpServerRequest {

//     private PipedStream pipedStream;
//     // MultiPartFormInputStream multiPartFormInputStream;
//     private UrlEncoded urlEncodedMap;
//     private string charset;
//     // private BufferedReader bufferedReader;
//     private string stringBody;


//     override
//     string getParameter(string name) {
//         return urlEncodedMap.getString(name);
//     }

//     override
//     List!(string) getParameterValues(string name) {
//         return urlEncodedMap.getValues(name);
//     }

//     override
//     Map!(string, List!(string)) getParameterMap() {
//         return urlEncodedMap;
//     }

//     private void decodeUrl() {
//         if(urlEncodedMap is null)
//             urlEncodedMap = new UrlEncoded();
//     }

//     // override
//     // Collection<Part> getParts() {
//     //     if (multiPartFormInputStream == null) {
//     //         return null;
//     //     } else {
//     //         try {
//     //             return multiPartFormInputStream.getParts();
//     //         } catch (IOException e) {
//     //             errorf("get multi part exception", e);
//     //             return null;
//     //         }
//     //     }
//     // }

//     // override
//     // Part getPart(string name) {
//     //     if (multiPartFormInputStream == null) {
//     //         return null;
//     //     } else {
//     //         try {
//     //             return multiPartFormInputStream.getPart(name);
//     //         } catch (IOException e) {
//     //             errorf("get multi part exception", e);
//     //             return null;
//     //         }
//     //     }
//     // }

//     InputStream getInputStream() {
//         if (pipedStream is null) {
//             return null;
//         } else {
//             try {
//                 return pipedStream.getInputStream();
//             } catch (IOException e) {
//                 errorf("get input stream exception", e);
//                 return null;
//             }
//         }
//     }

//     // override
//     // BufferedReader getBufferedReader() {
//     //     if (bufferedReader != null) {
//     //         return bufferedReader;
//     //     } else {
//     //         if (pipedStream == null) {
//     //             return null;
//     //         } else {
//     //             try {
//     //                 bufferedReader = new BufferedReader(new InputStreamReader(pipedStream.getInputStream()));
//     //                 return bufferedReader;
//     //             } catch (IOException e) {
//     //                 errorf("get buffered reader exception", e);
//     //                 return null;
//     //             }
//     //         }
//     //     }
//     // }

//     override
//     string getStringBody(string charset) {
//         if (stringBody != null) {
//             return stringBody;
//         } else {
//             InputStream inputStream = getInputStream();
//             if (inputStream is null) {
//                 return null;
//             } else {
//                 try  {
//                     // stringBody = IO.toString(inputStream, Charset.forName(charset));
//                     int size = inputStream.available();
//                     warningf("available: %d", size);
//                     byte[] buffer = new byte[size];
//                     inputStream.read(buffer);
//                     stringBody = cast(string)buffer;
//                     return stringBody;
//                 } catch (IOException e) {
//                     errorf("get string body exception", e);
//                     return null;
//                 }
//             }
//         }
//     }

//     override
//     string getStringBody() {
//         return getStringBody(charset);
//     }

//     // override
//     // <T> T getJsonBody(Class<T> clazz) {
//     //     return Json.toObject(getStringBody(), clazz);
//     // }

//     // override
//     // <T> T getJsonBody(GenericTypeReference<T> typeReference) {
//     //     return Json.toObject(getStringBody(), typeReference);
//     // }

//     // override
//     // JsonObject getJsonObjectBody() {
//     //     return Json.toJsonObject(getStringBody());
//     // }

//     // override
//     // JsonArray getJsonArrayBody() {
//     //     return Json.toJsonArray(getStringBody());
//     // }

// }
