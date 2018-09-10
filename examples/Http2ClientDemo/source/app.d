
import hunt.http.codec.http.model;

import hunt.http.client.http.ClientHTTPHandler;
import hunt.http.client.http.HTTP2Client;
import hunt.http.client.http.HTTPClientConnection;
import hunt.http.client.http.HTTPClientRequest;
import hunt.http.codec.http.stream.HTTP2Configuration;
import hunt.http.codec.http.stream.HTTPConnection;
import hunt.http.codec.http.stream.HTTPOutputStream;
import hunt.http.codec.websocket.frame;
import hunt.http.codec.websocket.model.IncomingFrames;
import hunt.http.codec.websocket.stream.WebSocketConnection;
import hunt.http.codec.websocket.stream.WebSocketPolicy;

import hunt.util.concurrent.Promise;
import hunt.util.concurrent.FuturePromise;

import hunt.net.secure.SecureSessionFactory;
import hunt.net.secure.conscrypt;

import hunt.http.helper;
import hunt.datetime;
import hunt.logging;

import std.datetime;
import std.conv;
import std.stdio;

/**
sudo apt-get install libssl-dev
*/

void main(string[] args) {
	HTTP2Client client = new HTTP2Client(new HTTP2Configuration());
    HTTPClientConnection connection = client.connect("127.0.0.1", 8080).get();
    HTTPClientRequest request = new HTTPClientRequest("GET", "/index");
    FuturePromise!WebSocketConnection promise = new FuturePromise!WebSocketConnection();
    connection.upgradeWebSocket(request, WebSocketPolicy.newClientPolicy(), promise, 
        
        new class ClientHTTPHandler.Adapter {
            override
            public bool messageComplete(MetaData.Request request, MetaData.Response response,
                                           HTTPOutputStream output,
                                           HTTPConnection connection) {
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
