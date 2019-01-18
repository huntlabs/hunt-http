module test.http.router.handler.error;

import hunt.http.$;
import hunt.http.codec.http.model.HttpStatus;
import hunt.http.server.Http2ServerBuilder;
import hunt.Assert;
import hunt.util.Test;
import test.http.router.handler.AbstractHttpHandlerTest;

import hunt.concurrency.Phaser;



/**
 * 
 */
public class TestErrorHandler extends AbstractHttpHandlerTest {

    
    public void test() {
        Phaser phaser = new Phaser(3);

        Http2ServerBuilder httpServer = $.httpServer();
        httpServer.router().get("/").handler(ctx -> ctx.write("hello world! ").next())
                  .router().get("/").handler(ctx -> ctx.end("end message"))
                  .listen(host, port);

        $.httpClient().get(uri ~ "/").submit()
         .thenAccept(res -> {
             Assert.assertThat(res.getStatus(), is(HttpStatus.OK_200));
             Assert.assertThat(res.getStringBody(), is("hello world! end message"));
             writeln(res.getStringBody());
             phaser.arrive();
         });

        $.httpClient().get(uri ~ "/hello").submit()
         .thenAccept(res -> {
             Assert.assertThat(res.getStatus(), is(HttpStatus.NOT_FOUND_404));
             writeln(res.getStringBody());
             phaser.arrive();
         });

        phaser.arriveAndAwaitAdvance();
        httpServer.stop();
        $.httpClient().stop();
    }
}
