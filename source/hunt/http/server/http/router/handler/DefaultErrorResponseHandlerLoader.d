module hunt.http.server.http.router.handler.DefaultErrorResponseHandlerLoader;

// import hunt.http.utils.ServiceUtils;
import kiss.logger;

import hunt.util.exception;

import hunt.http.environment;
import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.model.HttpStatus;
import hunt.http.server.http.router.RoutingContext;
import hunt.http.server.http.router.Handler;
import hunt.http.server.http.router.RoutingContext;

import std.conv;


/**
 * 
 */
abstract class AbstractErrorResponseHandler : Handler {
    override
    void handle(RoutingContext ctx) {
        if (ctx.hasNext()) {
            try {
                ctx.next();
            } catch (Exception t) {
                errorf("http handler exception", t);
                if (!ctx.getResponse().isCommitted()) {
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

    override
    void render(RoutingContext ctx, int status, Throwable t) {

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
           .write("<footer><em>powered by Hunt " ~ Version ~ "</em></footer>")
           .write("</body>")
           .end("</html>");
    }

}


/**
 * 
 */
class DefaultErrorResponseHandlerLoader {
    private static DefaultErrorResponseHandlerLoader ourInstance;

    static this()
    {
        ourInstance = new DefaultErrorResponseHandlerLoader();
    }

    static DefaultErrorResponseHandlerLoader getInstance() {
        return ourInstance;
    }

    private AbstractErrorResponseHandler handler;

    private this() {
        // handler = ServiceUtils.loadService(AbstractErrorResponseHandler.class, new DefaultErrorResponseHandler());
        // info("load AbstractErrorResponseHandler, selected -> %s", handler.getClass().getName());
        implementationMissing(false);
        handler = new DefaultErrorResponseHandler();
    }

    AbstractErrorResponseHandler getHandler() {
        return handler;
    }
}
