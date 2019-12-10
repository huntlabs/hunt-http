module hunt.http.routing.handler.ErrorResponseHandler;

import hunt.http.routing.RoutingContext;

import hunt.http.Version;
import hunt.http.HttpHeader;
import hunt.http.HttpStatus;

import hunt.logging.ConsoleLogger;
import hunt.Exceptions;

import std.conv;
import std.concurrency : initOnce;


/**
 * 
 */
abstract class ErrorResponseHandler : RouteHandler {

    void handle(RoutingContext context) {
        if (context.hasNext()) {
            try {
                context.next();
            } catch (Exception t) {
                version(HUNT_DEBUG) errorf("http handler exception", t.msg);
                if (!context.isCommitted()) {
                    render(context, HttpStatus.INTERNAL_SERVER_ERROR_500, t);
                    context.fail(t);
                }
            }
        } else {
            render(context, HttpStatus.NOT_FOUND_404, null);
            context.succeed(true);
        }
    }

    abstract void render(RoutingContext context, int status, Exception ex);
}


/**
 * 
 */
class DefaultErrorResponseHandler : ErrorResponseHandler {
    private __gshared DefaultErrorResponseHandler inst;

    static DefaultErrorResponseHandler Default() {
        return initOnce!inst(new DefaultErrorResponseHandler());
    }

    static void Default(DefaultErrorResponseHandler handler) {
        inst = handler;
    }

    override void render(RoutingContext context, int status, Exception t) {

        HttpStatusCode code = HttpStatus.getCode(status); 
        if(code == HttpStatusCode.Null)
            code = HttpStatusCode.INTERNAL_SERVER_ERROR;
        
        string title = status.to!string() ~ " " ~ code.getMessage();
        string content;
        if(status == HttpStatus.NOT_FOUND_404) {
            content = "The resource " ~ context.getURI().getPath() ~ " is not found";
        } else if(status == HttpStatus.INTERNAL_SERVER_ERROR_500) {
            content = "The server internal error. <br/>" ~ (t !is null ? t.msg : "");
        } else {
            content = title ~ "<br/>" ~ (t !is null ? t.msg : "");
        }

        context.setStatus(status);
        context.getResponseHeaders().put(HttpHeader.CONTENT_TYPE, "text/html");
        context.write("<!DOCTYPE html>")
           .write("<html>")
           .write("<head>")
           .write("<title>")
           .write(title)
           .write("</title>")
           .write("</head>")
           .write("<body>")
           .write("<h1> " ~ title ~ " </h1>")
           .write("<p>" ~ content ~ "</p>")
           .write("<hr/>")
           .write("<footer><em>powered by Hunt HTTP " ~ Version ~"</em></footer>")
           .write("</body>")
           .end("</html>");
    }

}
