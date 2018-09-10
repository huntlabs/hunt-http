module test.http;

import hunt.http.client.http2.SimpleHttpClient;
import hunt.http.client.http2.SimpleResponse;
import hunt.http.utils.concurrent.Promise;

import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.Phaser;

public class SimpleHttpClientDemo4 {

    public static void main(string[] args) throws InterruptedException, ExecutionException {
        SimpleHttpClient client = new SimpleHttpClient();

        Phaser phaser = new Phaser(10 + 20 + 1);
        for (int i = 0; i < 10; i++) {
            client.post("http://localhost:3333/postData")
                  .put("RequestId", i ~ "_")
                  .body("test post data, hello foo " ~ i)
                  .submit(r -> {
                      writeln(r.getStringBody());
                      phaser.arrive();
                  });
        }

        for (int i = 10; i < 30; i++) {
            client.post("http://localhost:3333/postData")
                  .put("RequestId", i ~ "_")
                  .body("test post data, hello foo " ~ i)
                  .submit()
                  .thenAcceptAsync(r -> {
                      writeln(r.getStringBody());
                      phaser.arrive();
                  });
        }

        for (int i = 30; i < 40; i++) {
            CompletableFuture<SimpleResponse> future = client
                    .post("http://localhost:3333/postData")
                    .put("RequestId", i ~ "_")
                    .body("test post data, hello foo " ~ i)
                    .submit();
            SimpleResponse r = future.get();
            writeln(r.getStringBody());
        }

        phaser.arriveAndAwaitAdvance();
        client.stop();
    }

}
