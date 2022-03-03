module hunt.http.routing.handler.DefaultErrorResponseHandler;

import hunt.http.routing.RoutingContext;
import hunt.http.routing.handler.ErrorResponseHandler;

import hunt.http.Version;
import hunt.http.HttpHeader;
import hunt.http.HttpStatus;

import hunt.logging;
import hunt.Exceptions;

import std.conv;
import std.concurrency : initOnce;
import std.range;

/**
 * 
 */
class DefaultErrorResponseHandler : ErrorResponseHandler {

    this() {
        super(HttpStatus.NOT_FOUND_404);
    }

    override void render(RoutingContext context, int status, Exception t) {
        renderErrorPage(context, status, t);
    }
}
