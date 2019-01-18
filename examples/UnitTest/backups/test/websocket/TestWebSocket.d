module test.websocket;

import hunt.http.$;
import hunt.http.client.websocket.SimpleWebSocketClient;
import hunt.http.server.websocket.SimpleWebSocketServer;
import hunt.http.utils.RandomUtils;
import hunt.collection.BufferUtils;
import hunt.util.runners.Parameterized;

import java.nio.charset.StandardCharsets;
import hunt.collection.ArrayList;
import java.util.Collection;
import hunt.collection.List;
import hunt.concurrency.CountDownLatch;

/**
 * 
 */
abstract public class TestWebSocket {

    @Parameterized.Parameter
    public Run r;

    static class Run {
        int port;
        int maxMsg;
        string testName;
        SimpleWebSocketServer server;
        SimpleWebSocketClient client;
        string protocol;

        override
        public string toString() {
            return testName;
        }
    }

    @Parameterized.Parameters(name = "{0}")
    public static Collection<Run> data() {
        List<Run> data = new ArrayList<>();
        Run run = new Run();
        run.port = (int) RandomUtils.random(3000, 65534);
        run.maxMsg = 10;
        run.testName = "Test the WebSocket";
        run.server = $.createWebSocketServer();
        run.client = $.createWebSocketClient();
        run.protocol = "ws";
        data.add(run);

        run = new Run();
        run.port = (int) RandomUtils.random(3000, 65534);
        run.maxMsg = 10;
        run.testName = "Test the secure WebSocket";
        run.server = $.createSecureWebSocketServer();
        run.client = $.createSecureWebSocketClient();
        run.protocol = "wss";
        data.add(run);
        return data;
    }

    public void testServerAndClient(List<string> extensions) throws InterruptedException {
        SimpleWebSocketServer server = r.server;
        SimpleWebSocketClient client = r.client;
        string host = "localhost";
        string protocol = r.protocol;
        int port = r.port;
        int count = r.maxMsg;

        CountDownLatch latch = new CountDownLatch(count * 2 + 1);
        server.webSocket("/helloWebSocket")
              .onConnect(conn -> {
                  for (int i = 0; i < count; i++) {
                      conn.sendText("Msg: " ~ i);
                      conn.sendData(("Data: " ~ i).getBytes(StandardCharsets.UTF_8));
                  }
              })
              .onText((text, conn) -> {
                  writeln("Server received: " ~ text);
                  latch.countDown();
              })
              .listen(host, port);

        client.webSocket(protocol ~ "://" ~ host ~ ":" ~ port ~ "/helloWebSocket")
              .putExtension(extensions)
              .onText((text, conn) -> {
                  writeln("Client received: " ~ text);
                  latch.countDown();
              })
              .onData((buf, conn) -> {
                  writeln("Client received: " ~ BufferUtils.toString(buf));
                  latch.countDown();
              })
              .connect()
              .thenAccept(conn -> conn.sendText("Hello Websocket"));

        latch.await();
        server.stop();
        client.stop();
    }

    abstract void test() throws Exception;
}
