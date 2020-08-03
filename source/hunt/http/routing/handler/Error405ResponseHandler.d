module hunt.http.routing.handler.Error405ResponseHandler;

import hunt.http.routing.RoutingContext;
import hunt.http.routing.handler.ErrorResponseHandler;

import hunt.http.Version;
import hunt.http.HttpHeader;
import hunt.http.HttpStatus;

import hunt.logging.ConsoleLogger;
import hunt.Exceptions;

import std.conv;
import std.concurrency : initOnce;
import std.range;

/**
 * 
 */
class Error405ResponseHandler : ErrorResponseHandler {

    this() {
        super(HttpStatus.METHOD_NOT_ALLOWED_405);
    }

    override void render(RoutingContext context, int status, Exception t) {
        renderErrorPage(context, status, t);
    }
}
