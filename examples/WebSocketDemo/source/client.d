
import hunt.http.codec.http.model;

import hunt.http.client.ClientHttpHandler;
import hunt.http.client.HttpClient;
import hunt.http.client.HttpClientConnection;
import hunt.http.client.HttpClientRequest;
import hunt.http.codec.http.stream.Http2Configuration;
import hunt.http.codec.http.stream.HttpConnection;
import hunt.http.codec.http.stream.HttpOutputStream;
import hunt.http.codec.websocket.frame;
import hunt.http.codec.websocket.model.IncomingFrames;
import hunt.http.codec.websocket.stream.WebSocketConnection;
import hunt.http.codec.websocket.stream.WebSocketPolicy;

import hunt.util.concurrent.Promise;
import hunt.util.concurrent.FuturePromise;

import hunt.net.secure.SecureSessionFactory;
import hunt.net.secure.conscrypt;

import hunt.datetime;
import hunt.logging;

import std.datetime;
import std.conv;
import std.stdio;

/**
sudo apt-get install libssl-dev
*/

void main(string[] args) {
	HttpClient client = new HttpClient(new Http2Configuration());
    HttpClientConnection connection = client.connect("127.0.0.1", 8080).get();
    HttpClientRequest request = new HttpClientRequest("GET", "/index");
    FuturePromise!WebSocketConnection promise = new FuturePromise!WebSocketConnection();
    connection.upgradeWebSocket(request, WebSocketPolicy.newClientPolicy(), promise, 
        
        new class ClientHttpHandler.Adapter {
            override
            public bool messageComplete(HttpRequest request, HttpResponse response,
                                           HttpOutputStream output,
                                           HttpConnection connection) {
                tracef("upgrade websocket success: " ~ response.toString());
                return true;
            }
        }, 
        
        new class IncomingFrames {
            override
            public void incomingError(Exception t) {

            }

            override
            public void incomingFrame(Frame frame) {
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
        });

        WebSocketConnection webSocketConnection = promise.get();
        webSocketConnection.sendText("Hello WebSocket").thenAccept( (r) {
            tracef("Client sends text frame success.");
        });

        client.stop();

}
