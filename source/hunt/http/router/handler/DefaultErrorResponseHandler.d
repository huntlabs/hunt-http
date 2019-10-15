module hunt.http.router.handler.DefaultErrorResponseHandler;

import hunt.http.router.RoutingHandler;

import hunt.http.Environment;
import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.model.HttpStatus;
import hunt.http.router.RoutingContext;

import hunt.logging;
import hunt.Exceptions;

import std.conv;
import std.concurrency : initOnce;


/**
 * 
 */
abstract class AbstractErrorResponseHandler : IRoutingHandler {

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

    static DefaultErrorResponseHandler Default() {
        __gshared DefaultErrorResponseHandler inst;
        return initOnce!inst(new DefaultErrorResponseHandler());
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
        

        ctx.setStatus(status).put(HttpHeader.CONTENT_TYPE, "text/html")
           .write("<!DOCTYPE html>")
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
