module hunt.http.routing.handler.DefaultErrorResponseHandler;

import hunt.http.routing.RoutingContext;

import hunt.http.Version;
import hunt.http.HttpHeader;
import hunt.http.HttpStatus;

import hunt.logging;
import hunt.Exceptions;

import std.conv;
import std.concurrency : initOnce;


/**
 * 
 */
abstract class AbstractErrorResponseHandler : RouteHandler {

    void handle(RoutingContext ctx) {
        if (ctx.hasNext()) {
            try {
                ctx.next();
            } catch (Exception t) {
                errorf("http handler exception", t);
                if (!ctx.isCommitted()) {
                    render(ctx, HttpStatus.INTERNAL_SERVER_ERROR_500, t);
                    ctx.fail(t);
                }
            }
        } else {
            render(ctx, HttpStatus.NOT_FOUND_404, null);
            ctx.succeed(true);
        }
    }

    abstract void render(RoutingContext ctx, int status, Throwable t);
}


/**
 * 
 */
class DefaultErrorResponseHandler : AbstractErrorResponseHandler {
    private __gshared DefaultErrorResponseHandler inst;

    static DefaultErrorResponseHandler Default() {
        return initOnce!inst(new DefaultErrorResponseHandler());
    }

    static void Default(DefaultErrorResponseHandler handler) {
        inst = handler;
    }

    override void render(RoutingContext ctx, int status, Throwable t) {

        HttpStatusCode code = HttpStatus.getCode(status); 
        if(code == HttpStatusCode.Null)
            code = HttpStatusCode.INTERNAL_SERVER_ERROR;
        
        string title = status.to!string() ~ " " ~ code.getMessage();
        string content;
        if(code == HttpStatusCode.NOT_FOUND) {
                content = "The resource " ~ ctx.getURI().getPath() ~ " is not found";
        }
        else if(code == HttpStatusCode.INTERNAL_SERVER_ERROR) {
                content = "The server internal error. <br/>" ~ (t !is null ? t.msg : "");
        }
        else {
                content = title ~ "<br/>" ~ (t !is null ? t.msg : "");
        }
        

        ctx.setStatus(status);
        ctx.getResponseHeaders().put(HttpHeader.CONTENT_TYPE, "text/html");
        ctx.write("<!DOCTYPE html>")
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
