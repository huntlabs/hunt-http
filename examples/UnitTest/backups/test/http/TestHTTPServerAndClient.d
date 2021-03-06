module test.http;

import hunt.http.$;
import hunt.http.client.SimpleHttpClient;
import hunt.http.client.SimpleHttpClientConfiguration;
import hunt.http.HttpHeader;
import hunt.util.MimeType;
import hunt.http.server.SimpleHttpServer;
import hunt.http.server.SimpleHttpServerConfiguration;
import hunt.http.server.SimpleResponse;
import hunt.Assert;
import hunt.util.Test;
import hunt.util.runner.RunWith;
import hunt.util.runners.Parameterized;
import hunt.util.runners.Parameterized.Parameter;
import hunt.util.runners.Parameterized.Parameters;

import java.io.PrintWriter;
import hunt.collection.ArrayList;
import java.util.Collection;
import hunt.collection.List;
import hunt.concurrency.CountDownLatch;
import hunt.concurrency.Phaser;
import hunt.concurrency.atomic.AtomicInteger;



/**
 * 
 */

public class TestHttpServerAndClient {

    @Parameter
    public Run r;

    static class Run {
        SimpleHttpClientConfiguration clientConfig;
        SimpleHttpServerConfiguration serverConfig;
        string requestURL;
        string quitURL;
        int port;
        int maxMsg;
        string testName;

        override
        public string toString() {
            return testName;
        }
    }

    @Parameters(name = "{0}")
    public static Collection<Run> data() {
        List<Run> data = new ArrayList<>();
        Run run = new Run();
        run.clientConfig = new SimpleHttpClientConfiguration();
        run.serverConfig = new SimpleHttpServerConfiguration();
        run.port = 1332;
        run.maxMsg = 5;
        run.requestURL = "http://localhost:" ~ run.port ~ "/";
        run.quitURL = "http://localhost:" ~ run.port ~ "/quit";
        run.testName = "Test HTTP server and client";
        data.add(run);

        run = new Run();
        run.clientConfig = new SimpleHttpClientConfiguration();
        run.clientConfig.setSecureConnectionEnabled(true); // enable HTTPs
        run.serverConfig = new SimpleHttpServerConfiguration();
        run.serverConfig.setSecureConnectionEnabled(true);
        run.port = 1333;
        run.maxMsg = 15;
        run.requestURL = "https://localhost:" ~ run.port ~ "/";
        run.quitURL = "https://localhost:" ~ run.port ~ "/quit";
        run.testName = "Test HTTPs server and client";
        data.add(run);

        return data;
    }

    
    public void test() throws InterruptedException {
        SimpleHttpServer server = $.createHttpServer(r.serverConfig);
        SimpleHttpClient client = $.createHttpClient(r.clientConfig);
        int port = r.port;
        int maxMsg = r.maxMsg;
        CountDownLatch countDownLatch = new CountDownLatch(maxMsg + 1);

        AtomicInteger msgCount = new AtomicInteger();
        server.headerComplete(r -> r.messageComplete(request -> {
            SimpleResponse response = request.getResponse();
            string path = request.getURI().getPath();

            writeln("server receives message -> " ~ request.getStringBody());
            response.getFields().put(HttpHeader.CONTENT_TYPE, MimeTypes.Type.TEXT_PLAIN.asString());
            switch (path) {
                case "/": {
                    msgCount.incrementAndGet();
                    try (PrintWriter writer = response.getPrintWriter()) {
                        writer.print("response message [" ~ request.getStringBody() ~ "]");
                    }
                }
                break;
                case "/quit": {
                    try (PrintWriter writer = response.getPrintWriter()) {
                        writer.print("bye!");
                    }
                }
                break;
            }
        })).listen("localhost", port);

        for (int i = 0; i < maxMsg; i++) {
            client.post(r.requestURL).body("hello world" ~ i ~ "!").submit().thenAcceptAsync(r -> {
                writeln("client receives message -> " ~ r.getStringBody());
                countDownLatch.countDown();
            });
        }
        client.post(r.quitURL).body("quit test").submit().thenAcceptAsync(r -> {
            writeln("client receives message -> " ~ r.getStringBody());
            countDownLatch.countDown();
        });

        countDownLatch.await();
        Assert.assertThat(msgCount.get(), is(maxMsg));
        client.stop();
        server.stop();
    }
}
