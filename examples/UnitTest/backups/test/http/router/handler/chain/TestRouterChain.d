module test.http.router.handler.chain;

import hunt.http.$;
import hunt.http.client.http2.SimpleResponse;
import hunt.http.server.Http2ServerBuilder;
import hunt.http.utils.concurrent.Promise;
import hunt.Assert;
import hunt.util.Test;
import test.http.router.handler.AbstractHttpHandlerTest;

import java.util.concurrent.TimeUnit;



/**
 * 
 */
public class TestRouterChain extends AbstractHttpHandlerTest {

    
    public void testChain() {
        Http2ServerBuilder httpServer = $.httpServer();
        httpServer.router().get("/routerChain").asyncHandler(ctx -> {
            ctx.setAttribute("reqId", 1000);
            ctx.write("enter router 1\r\n")
               .<string>nextFuture()
               .thenAccept(result -> ctx.write("router 1 success\r\n").end(result))
               .exceptionally(ex -> {
                   ctx.end(ex.getMessage());
                   return null;
               });
        }).router().get("/routerChain").asyncHandler(ctx -> {
            Integer reqId = (Integer) ctx.getAttribute("reqId");
            ctx.write("enter router 2, request id " ~ reqId ~ "\r\n")
               .<string>nextFuture()
               .thenAccept(result -> ctx.write("router 2 success, request id " ~ reqId ~ "\r\n").succeed(result))
               .exceptionally(ex -> {
                   ctx.fail(ex);
                   return null;
               });
        }).router().get("/routerChain").asyncHandler(ctx -> {
            Integer reqId = (Integer) ctx.getAttribute("reqId");
            ctx.write("enter router 3, request id " ~ reqId ~ "\r\n")
               .<string>complete()
               .thenAccept(result -> ctx.write("router 3 success, request id " ~ reqId ~ "\r\n").succeed(result))
               .exceptionally(ex -> {
                   ctx.fail(ex);
                   return null;
               });
            ctx.succeed("request complete");
        }).listen(host, port);

        SimpleResponse response = $.httpClient().get(uri ~ "/routerChain").submit().get(2, TimeUnit.SECONDS);
        writeln(response.getStringBody());
        Assert.assertThat(response.getStringBody(), is(
                "enter router 1\r\n" ~
                        "enter router 2, request id 1000\r\n" ~
                        "enter router 3, request id 1000\r\n" ~
                        "router 3 success, request id 1000\r\n" ~
                        "router 2 success, request id 1000\r\n" ~
                        "router 1 success\r\n" ~
                        "request complete"));
        httpServer.stop();
        $.httpClient().stop();
    }
}
