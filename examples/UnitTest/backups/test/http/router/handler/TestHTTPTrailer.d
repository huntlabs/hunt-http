module test.http.router.handler;

import hunt.http.$;
import hunt.http.client.http2.SimpleHttpClient;
import hunt.http.client.http2.SimpleHttpClientConfiguration;
import hunt.http.codec.http.model.HttpFields;
import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.model.HttpStatus;
import hunt.http.codec.http.stream.HttpOutputStream;
import hunt.http.server.http.Http2ServerBuilder;
import hunt.http.server.http.SimpleHttpServerConfiguration;
import hunt.container.BufferUtils;
import hunt.util.Assert;
import hunt.util.Test;

import java.io.IOException;
import java.util.concurrent.Phaser;



/**
 * 
 */
public class TestHTTPTrailer extends AbstractHttpHandlerTest {

    
    public void test() {
        Phaser phaser = new Phaser(3);

        Http2ServerBuilder httpServer = $.httpServer();
        startHttpServer(httpServer);

        SimpleHttpClient httpClient = $.createHttpClient();
        testServerResponseTrailer(phaser, httpClient);
        testClientPostTrailer(phaser, httpClient);

        phaser.arriveAndAwaitAdvance();
        httpServer.stop();
        httpClient.stop();
    }

    
    public void testHttp2() {
        Phaser phaser = new Phaser(3);

        SimpleHttpServerConfiguration serverConfiguration = new SimpleHttpServerConfiguration();
        serverConfiguration.setSecureConnectionEnabled(true);
        Http2ServerBuilder httpsServer = $.httpServer(serverConfiguration);
        startHttpServer(httpsServer);

        SimpleHttpClientConfiguration clientConfiguration = new SimpleHttpClientConfiguration();
        clientConfiguration.setSecureConnectionEnabled(true);
        SimpleHttpClient httpsClient = new SimpleHttpClient(clientConfiguration);
        testServerResponseTrailer(phaser, httpsClient);
        testClientPostTrailer(phaser, httpsClient);

        phaser.arriveAndAwaitAdvance();
        httpsServer.stop();
        httpsClient.stop();
    }

    private void testServerResponseTrailer(Phaser phaser, SimpleHttpClient httpClient) {
        httpClient.get(uri ~ "/trailer").submit()
                  .thenAccept(res -> {
                      Assert.assertThat(res.getStatus(), is(HttpStatus.OK_200));
                      Assert.assertThat(res.getFields().get(HttpHeader.CONTENT_TYPE), is("text/plain"));
                      writeln(res.getFields());
                      Assert.assertThat(res.getStringBody().length, greaterThan(0));
                      writeln(res.getStringBody());
                      Assert.assertThat(res.getTrailerSupplier(), notNullValue());
                      HttpFields trailer = res.getTrailerSupplier().get();
                      Assert.assertThat(trailer.size(), greaterThan(0));
                      Assert.assertThat(trailer.get("Foo"), is("s1"));
                      Assert.assertThat(trailer.get("Bar"), is("s2"));
                      writeln(trailer);
                      phaser.arrive();
                  });
    }

    private void testClientPostTrailer(Phaser phaser, SimpleHttpClient httpClient) {
        httpClient.post(uri ~ "/postTrailer").setTrailerSupplier(() -> {
            HttpFields trailer = new HttpFields();
            trailer.add("ok", "my trailer");
            return trailer;
        }).output(out -> {
            try (HttpOutputStream output = out) {
                output.write(BufferUtils.toBuffer("hello"));
            } catch (IOException e) {
                e.printStackTrace();
            }
        }).submit().thenAccept(res -> {
            Assert.assertThat(res.getStatus(), is(HttpStatus.OK_200));
            Assert.assertThat(res.getStringBody().length, greaterThan(0));
            writeln(res.getStringBody());
            Assert.assertThat(res.getStringBody(), is("trailer : my trailer"));
            phaser.arrive();
        });
    }

    private void startHttpServer(Http2ServerBuilder httpServer) {
        httpServer.router().get("/trailer").handler(ctx -> {
            writeln("get request");
            ctx.put(HttpHeader.CONTENT_TYPE, "text/plain");
            ctx.getResponse().setTrailerSupplier(() -> {
                HttpFields trailer = new HttpFields();
                trailer.add("Foo", "s1");
                trailer.add("Bar", "s2");
                return trailer;
            });
            ctx.end("trailer test");
        }).router().post("/postTrailer").handler(ctx -> {
            writeln("post trailer");
            HttpFields trailer = ctx.getRequest().getTrailerSupplier().get();
            ctx.end("trailer : " ~ trailer.get("ok"));
        }).listen(host, port);
    }


}
