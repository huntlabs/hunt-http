module hunt.http.routing.handler.DefaultRouteHandler;

import hunt.http.routing.RoutingContext;
import hunt.http.routing.impl.RoutingContextImpl;
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
class DefaultRouteHandler : RouteHandler {

    // private HttpRequestOptions _options;

    this() {
        // this(new HttpRequestOptions());
    }

    // this(HttpRequestOptions options) {
    //     this._options = options;
    // }

    // HttpRequestOptions getConfiguration() {
    //     return _options;
    // }

    // void setConfiguration(HttpRequestOptions options) {
    //     this._options = options;
    // }

    override void handle(RoutingContext context) {
        HttpServerRequest request = context.getRequest();
        
        if (context.isAsynchronousRead() || // receive content event has been listened
            (!request.isChunked() && request.getContentLength()<=0)) { // Or request is not chunked and have no content
            context.next();
            return;
        }

        request.onHeaderComplete();
        request.onMessageComplete((HttpServerRequest req) { context.next(); });
        context.enableAsynchronousRead();

    }
}
