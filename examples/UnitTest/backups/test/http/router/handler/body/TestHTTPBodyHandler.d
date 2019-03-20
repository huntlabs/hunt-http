module test.http.router.handler.body;

import hunt.http.$;
import hunt.http.client.SimpleHttpClient;
import hunt.http.codec.http.encode.UrlEncoded;
import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.model.HttpStatus;
import hunt.http.codec.http.stream.HttpOutputStream;
import hunt.http.server.Http2ServerBuilder;
import hunt.http.utils.concurrent.Promise;
import hunt.Assert;
import hunt.util.Test;
import test.http.router.handler.AbstractHttpHandlerTest;

import java.io.IOException;
import hunt.collection.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.List;
import hunt.concurrency.Phaser;



/**
 * 
 */
public class TestHttpBodyHandler extends AbstractHttpHandlerTest {

    public void testPostData(Http2ServerBuilder server, SimpleHttpClient client) {
        StringBuilder bigData = new StringBuilder();
        int dataSize = 1024 * 1024;
        for (int i = 0; i < dataSize; i++) {
            bigData.append(i);
        }
        byte[] data = $.string.getBytes(bigData.toString());
        writeln("data len: " ~ data.length);

        Phaser phaser = new Phaser(5);

        server.router().post("/data").handler(ctx -> {
            // small data test case
            writeln(ctx.getStringBody());
            Assert.assertThat(ctx.getStringBody(), is("test post data"));
            ctx.end("server received data");
            phaser.arrive();
        }).router().post("/bigData").handler(ctx -> {
            // big data test case
            writeln("receive big data size: " ~ ctx.getContentLength());
            Assert.assertThat((int) ctx.getContentLength(), is(data.length));
            Assert.assertThat($.io.toString(ctx.getInputStream()), is(bigData.toString()));
            $.io.close(ctx.getInputStream());
            ctx.end("server received big data");
            phaser.arrive();
        }).listen(host, port);

        client.post(uri ~ "/data").body("test post data").submit()
              .thenAccept(res -> {
                  writeln(res.getStringBody());
                  Assert.assertThat(res.getStatus(), is(HttpStatus.OK_200));
                  Assert.assertThat(res.getStringBody(), is("server received data"));
                  phaser.arrive();
              });

        // post big data with content length
        client.post(uri ~ "/bigData").put(HttpHeader.CONTENT_LENGTH, data.length ~ "")
              .write(BufferUtils.toBuffer(data))
              .submit()
              .thenAccept(res -> {
                  Assert.assertThat(res.getStatus(), is(HttpStatus.OK_200));
                  Assert.assertThat(res.getStringBody(), is("server received big data"));
                  phaser.arrive();
              });

        phaser.arriveAndAwaitAdvance();
        server.stop();
        client.stop();
    }

    
    public void testPostDataHttp2() {
        Http2ServerBuilder server = $.httpsServer();
        SimpleHttpClient client = $.createHttpsClient();
        testPostData(server, client);
    }

    
    public void testPostDataHttp1() {
        Http2ServerBuilder server = $.httpServer();
        SimpleHttpClient client = $.createHttpClient();
        testPostData(server, client);
    }

    public void testPostBigDataUsingChunkedEncoding(Http2ServerBuilder server, SimpleHttpClient client) {
        StringBuilder bigData = new StringBuilder();
        int dataSize = 1024 * 1024;
        for (int i = 0; i < dataSize; i++) {
            bigData.append(i);
        }
        byte[] data = $.string.getBytes(bigData.toString());
        writeln("data len: " ~ data.length);

        Phaser phaser = new Phaser(3);

        server.router().post("/bigData").handler(ctx -> {
            // big data test case
            Assert.assertThat($.io.toString(ctx.getInputStream()), is(bigData.toString()));
            $.io.close(ctx.getInputStream());
            ctx.end("server received big data");
            writeln("receive big data size: " ~ ctx.getContentLength());
            phaser.arrive();
        }).listen(host, port);

        // post big data using chunked encoding
        List!(ByteBuffer) buffers = $.buffer.split(BufferUtils.toBuffer(data), 4 * 1024);
        Promise.Completable<HttpOutputStream> promise = new Promise.Completable<>();
        promise.thenAccept(output -> {
            try (HttpOutputStream out = output) {
                for (ByteBuffer buf : buffers) {
                    out.write(buf);
                }
            } catch (IOException e) {
                e.printStackTrace();
            }
        });
        client.post(uri ~ "/bigData").output(promise)
              .submit()
              .thenAccept(res -> {
                  Assert.assertThat(res.getStatus(), is(HttpStatus.OK_200));
                  Assert.assertThat(res.getStringBody(), is("server received big data"));
                  phaser.arrive();
              });
        phaser.arriveAndAwaitAdvance();
        server.stop();
        client.stop();
    }

    
    public void testPostBigDataUsingChunkedEncodingHttp2() {
        Http2ServerBuilder server = $.httpsServer();
        SimpleHttpClient client = $.createHttpsClient();
        testPostBigDataUsingChunkedEncoding(server, client);
    }

    
    public void testPostBigDataUsingChunkedEncodingHttp1() {
        Http2ServerBuilder server = $.httpServer();
        SimpleHttpClient client = $.createHttpClient();
        testPostBigDataUsingChunkedEncoding(server, client);
    }

    
    public void testPostForm() {
        Phaser phaser = new Phaser(3);

        Http2ServerBuilder httpServer = $.httpServer();
        httpServer.router().post("/content/form").handler(ctx -> {
            Assert.assertThat(ctx.getParameter("name"), is("你的名字"));
            Assert.assertThat(ctx.getParameter("intro"), is("我要送些东西给你 我的孩子 因为我们同是漂泊在世界的溪流中的"));
            ctx.end("server received form data");
            phaser.arrive();
        }).listen(host, port);

        $.httpClient().post(uri ~ "/content/form")
         .putFormParam("name", "你的名字")
         .putFormParam("intro", "我要送些东西给你 我的孩子 因为我们同是漂泊在世界的溪流中的")
         .submit()
         .thenAccept(res -> {
             Assert.assertThat(res.getStatus(), is(HttpStatus.OK_200));
             Assert.assertThat(res.getStringBody(), is("server received form data"));
             phaser.arrive();
         });

        phaser.arriveAndAwaitAdvance();
        httpServer.stop();
        $.httpClient().stop();
    }

    
    public void testQueryParam() {
        Phaser phaser = new Phaser(3);

        Http2ServerBuilder httpServer = $.httpServer();
        httpServer.router().get("/query").handler(ctx -> {
            Assert.assertThat(ctx.getParameter("name"), is("你的名字"));
            Assert.assertThat(ctx.getParameter("intro"), is("我要送些东西给你 我的孩子 因为我们同是漂泊在世界的溪流中的"));
            ctx.end("server received form data");
            phaser.arrive();
        }).listen(host, port);

        UrlEncoded enc = $.uri.encode();
        enc.put("name", "你的名字");
        enc.put("intro", "我要送些东西给你 我的孩子 因为我们同是漂泊在世界的溪流中的");
        $.httpClient().get(uri ~ "/query?" ~ enc.encode(StandardCharsets.UTF_8, true))
         .submit()
         .thenAccept(res -> {
             Assert.assertThat(res.getStatus(), is(HttpStatus.OK_200));
             Assert.assertThat(res.getStringBody(), is("server received form data"));
             phaser.arrive();
         });

        phaser.arriveAndAwaitAdvance();
        httpServer.stop();
        $.httpClient().stop();
    }

    
    public void testGetWithBody() {
        Phaser phaser = new Phaser(3);

        Http2ServerBuilder httpServer = $.httpServer();
        httpServer.router().get("/queryWithBody").handler(ctx -> {
            string body = ctx.getStringBody();
            writeln(body);
            Assert.assertThat(body, is("Get request with body"));
            ctx.end("receive: " ~ body);
            phaser.arrive();
        }).listen(host, port);

        $.httpClient().get(uri ~ "/queryWithBody").body("Get request with body")
         .submit()
         .thenAccept(res -> {
             Assert.assertThat(res.getStatus(), is(HttpStatus.OK_200));
             Assert.assertThat(res.getStringBody(), is("receive: Get request with body"));
             phaser.arrive();
         });

        phaser.arriveAndAwaitAdvance();
        httpServer.stop();
        $.httpClient().stop();
    }

}
