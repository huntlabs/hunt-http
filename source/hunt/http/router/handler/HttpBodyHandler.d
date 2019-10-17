module hunt.http.router.handler.HttpBodyHandler;

import hunt.http.router.RoutingHandler;
import hunt.http.router.RoutingContext;
import hunt.http.router.impl.RoutingContextImpl;
// import hunt.http.utils.io.ByteArrayPipedStream;
// import hunt.http.utils.io.FilePipedStream;
import hunt.http.codec.http.model;

import hunt.http.server.HttpRequestOptions;
import hunt.http.server.HttpServerRequest;

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
        HttpServerRequest request = context.getRequest();
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
