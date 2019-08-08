import hunt.http.codec.http.model;

import hunt.http.client.ClientHttpHandler;
import hunt.http.client.HttpClient;
import hunt.http.client.HttpClientConnection;
import hunt.http.client.HttpClientRequest;
import hunt.http.HttpOptions;
import hunt.http.HttpConnection;
import hunt.http.codec.http.stream.HttpOutputStream;
import hunt.http.codec.websocket.frame;
import hunt.http.codec.websocket.model.IncomingFrames;
import hunt.http.codec.websocket.stream.WebSocketConnection;
import hunt.http.codec.websocket.stream.WebSocketPolicy;

import hunt.concurrency.Promise;
import hunt.concurrency.Future;
import hunt.concurrency.FuturePromise;
import hunt.concurrency.CompletableFuture;

import hunt.net.secure.SecureSessionFactory;
import hunt.net.secure.conscrypt;

import hunt.util.DateTime;
import hunt.logging;

import std.datetime;
import std.conv;
import std.stdio;
import hunt.net.NetUtil;

/**
sudo apt-get install libssl-dev
*/
void main(string[] args) {

    NetUtil.startEventLoop();

    HttpClient client = new HttpClient(new HttpOptions());
    Future!(HttpClientConnection) conn = client.connect("127.0.0.1", 8080);

    HttpClientRequest request = new HttpClientRequest("GET", "/index");
    FuturePromise!WebSocketConnection promise = new FuturePromise!WebSocketConnection();
    IncomingFramesEx incomingFramesEx = new IncomingFramesEx();
    ClientHttpHandlerEx handlerEx = new ClientHttpHandlerEx();

    HttpClientConnection connection = conn.get();
    assert(connection !is null);

    connection.upgradeWebSocket(request, WebSocketPolicy.newClientPolicy(),
            promise, handlerEx, incomingFramesEx);

    WebSocketConnection webSocketConnection = promise.get();
    // webSocketConnection.sendText("Hello WebSocket").thenAccept((r) {
    //     tracef("Client sends text frame success.");
    // });

    webSocketConnection.sendData([0x12, 0x13]).thenAccept((r) {
        tracef("Client sends text frame success.");
    });

    client.stop();
}

class ClientHttpHandlerEx : AbstractClientHttpHandler {
    override public bool messageComplete(HttpRequest request,
            HttpResponse response, HttpOutputStream output, HttpConnection connection) {
        tracef("upgrade websocket success: " ~ response.toString());
        return true;
    }
}

class IncomingFramesEx : IncomingFrames {
    override public void incomingError(Exception t) {

    }

    override public void incomingFrame(Frame frame) {
        FrameType type = frame.getType();
        switch (type) {
        case FrameType.TEXT: {
                TextFrame textFrame = cast(TextFrame) frame;
                tracef("Client received: " ~ textFrame.toString() ~ ", " ~ textFrame.getPayloadAsUTF8());
                break;
            }

        default:
            warningf("Can't handle the frame of ", type);
            break;
        }
    }
}
