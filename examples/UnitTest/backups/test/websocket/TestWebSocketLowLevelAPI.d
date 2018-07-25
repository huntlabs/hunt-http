module test.websocket;

import hunt.http.client.http2.ClientHTTPHandler;
import hunt.http.client.http2.HTTP2Client;
import hunt.http.client.http2.HTTPClientConnection;
import hunt.http.client.http2.HTTPClientRequest;
import hunt.http.codec.http.model.MetaData;
import hunt.http.codec.http.stream.HTTP2Configuration;
import hunt.http.codec.http.stream.HTTPConnection;
import hunt.http.codec.http.stream.HTTPOutputStream;
import hunt.http.codec.websocket.frame.Frame;
import hunt.http.codec.websocket.frame.TextFrame;
import hunt.http.codec.websocket.model.IncomingFrames;
import hunt.http.codec.websocket.stream.WebSocketConnection;
import hunt.http.codec.websocket.stream.WebSocketPolicy;
import hunt.http.server.http.HTTP2Server;
import hunt.http.server.http.ServerHTTPHandler;
import hunt.http.server.http.WebSocketHandler;
import hunt.http.utils.RandomUtils;
import hunt.http.utils.concurrent.FuturePromise;
import hunt.util.Assert;
import hunt.util.Test;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;




/**
 * 
 */
public class TestWebSocketLowLevelAPI {

    private string host = "localhost";
    private int port = (int) RandomUtils.random(3000, 65534);

    
    public void test() {
        CountDownLatch latch = new CountDownLatch(2);
        HTTP2Server server = createServer(latch);
        HTTP2Client client = new HTTP2Client(new HTTP2Configuration());

        HTTPClientConnection connection = client.connect(host, port).get();
        HTTPClientRequest request = new HTTPClientRequest("GET", "/index");
        FuturePromise<WebSocketConnection> promise = new FuturePromise<>();

        connection.upgradeWebSocket(request, WebSocketPolicy.newClientPolicy(), promise, new ClientHTTPHandler.Adapter() {
            override
            public bool messageComplete(MetaData.Request request, MetaData.Response response,
                                           HTTPOutputStream output,
                                           HTTPConnection connection) {
                writeln("upgrade websocket success: " ~ response);
                return true;
            }
        }, new IncomingFrames() {
            override
            public void incomingError(Throwable t) {

            }

            override
            public void incomingFrame(Frame frame) {
                switch (frame.getType()) {
                    case TEXT: {
                        TextFrame textFrame = (TextFrame) frame;
                        writeln("Client received: " ~ textFrame ~ ", " ~ textFrame.getPayloadAsUTF8());
                        Assert.assertThat(textFrame.getPayloadAsUTF8(), is("OK"));
                        latch.countDown();
                    }
                }
            }
        });

        WebSocketConnection webSocketConnection = promise.get();
        webSocketConnection.sendText("Hello WebSocket").thenAccept(r -> writeln("Client sends text frame success."));

        latch.await(5, TimeUnit.SECONDS);
        server.stop();
        client.stop();
    }


    public HTTP2Server createServer(CountDownLatch latch) {
        HTTP2Server server = new HTTP2Server(host, port, new HTTP2Configuration(), new ServerHTTPHandlerAdapter() {

            override
            public bool messageComplete(MetaData.Request request, MetaData.Response response,
                                           HTTPOutputStream output,
                                           HTTPConnection connection) {
                return true;
            }
        }, new WebSocketHandler() {

            override
            public void onConnect(WebSocketConnection webSocketConnection) {
                webSocketConnection.sendText("OK").thenAccept(r -> writeln("Server sends text frame success."));
            }

            override
            public void onFrame(Frame frame, WebSocketConnection connection) {
                switch (frame.getType()) {
                    case TEXT: {
                        TextFrame textFrame = (TextFrame) frame;
                        writeln("Server received: " ~ textFrame ~ ", " ~ textFrame.getPayloadAsUTF8());
                        Assert.assertThat(textFrame.getPayloadAsUTF8(), is("Hello WebSocket"));
                        latch.countDown();
                    }
                }

            }
        });
        server.start();
        return server;
    }
}
