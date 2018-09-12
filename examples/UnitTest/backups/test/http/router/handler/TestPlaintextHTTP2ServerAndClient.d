module test.http.router.handler;

import hunt.http.$;
import hunt.http.client.http2.SimpleHttpClient;
import hunt.http.server.Http2ServerBuilder;
import hunt.util.Assert;
import hunt.util.Test;

import java.util.concurrent.CountDownLatch;



/**
 * 
 */
public class TestPlaintextHttp2ServerAndClient extends AbstractHttpHandlerTest {

    
    public void test() throws InterruptedException {
        int times = 10;
        CountDownLatch latch = new CountDownLatch(times);

        Http2ServerBuilder server = $.plaintextHttp2Server();
        server.router().post("/plaintextHttp2").handler(ctx -> {
            writeln("Server: " ~
                    ctx.getHttpVersion().asString() ~ "\r\n" ~
                    ctx.getFields() +
                    ctx.getStringBody() +
                    "\r\n-----------------------\r\n");
            ctx.end("test plaintext http2");
        }).listen(host, port);

        SimpleHttpClient client = $.plaintextHttp2Client();
        for (int i = 0; i < times; i++) {
            client.post(uri ~ "/plaintextHttp2").body("post data").submit()
                  .thenAccept(res -> {
                      writeln("Client: " ~
                              res.getStatus() ~ " " ~ res.getHttpVersion().asString() ~ "\r\n" ~
                              res.getFields() +
                              res.getStringBody() +
                              "\r\n-----------------------\r\n");
                      Assert.assertThat(res.getStringBody(), is("test plaintext http2"));
                      latch.countDown();
                      writeln("Remain task: " ~ latch.getCount());
                  });
        }

        latch.await();
        writeln("Completed all tasks.");

        server.stop();
        client.stop();
    }
}
