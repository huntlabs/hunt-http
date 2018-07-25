module test.http.router.handler.template;

import hunt.http.$;
import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.model.HttpStatus;
import hunt.http.server.http.HTTP2ServerBuilder;
import hunt.util.Assert;
import hunt.util.Test;
import test.http.router.handler.AbstractHTTPHandlerTest;

import java.util.concurrent.Phaser;




/**
 * 
 */
public class TestTemplate extends AbstractHTTPHandlerTest {

    
    public void test() {
        Phaser phaser = new Phaser(2);

        HTTP2ServerBuilder httpServer = $.httpServer();
        httpServer.router().get("/example").handler(ctx -> {
            ctx.put(HttpHeader.CONTENT_TYPE, "text/plain");
            ctx.renderTemplate("template/example.mustache", new Example());
        }).listen(host, port);

        $.httpClient().get(uri ~ "/example").submit()
         .thenAccept(res -> {
             Assert.assertThat(res.getStatus(), is(HttpStatus.OK_200));
             Assert.assertThat(res.getFields().get(HttpHeader.CONTENT_TYPE), is("text/plain"));
             Assert.assertThat(res.getStringBody().length, greaterThan(0));
             writeln(res.getStringBody());
             phaser.arrive();
         });

        phaser.arriveAndAwaitAdvance();
        httpServer.stop();
        $.httpClient().stop();
    }

}
