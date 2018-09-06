
import hunt.http.codec.http.model;
import hunt.http.codec.http.stream;
import hunt.http.codec.websocket.frame;
import hunt.http.codec.websocket.model;
import hunt.http.codec.websocket.stream.WebSocketConnection;

import hunt.http.server.http.HTTP2Server;
import hunt.http.server.http.ServerHTTPHandler;
import hunt.http.server.http.WebSocketHandler;


import hunt.logging;

import std.file;
import std.path;
import std.stdio;


/**
openssl genrsa -out ca.key 4096
openssl req -new -x509 -days 365 -key ca.key -out ca.crt
openssl genrsa -out server.key 4096
openssl req -new -key server.key -out server.csr
openssl x509 -req -days 365 -in server.csr -CA ca.crt -CAkey ca.key -set_serial 01 -out server.crt
*/

void main(string[] args)
{
    HTTP2Server server = new HTTP2Server("0.0.0.0", 8080, new HTTP2Configuration(), 
        new class ServerHTTPHandlerAdapter {

            override
            bool messageComplete(MetaData.Request request, MetaData.Response response,
                                           HTTPOutputStream output,
                                           HTTPConnection connection) {
                return true;
            }
        }, 

        new class WebSocketHandler {
            override
            void onConnect(WebSocketConnection webSocketConnection) {
                webSocketConnection.sendText("OK").thenAccept( (r) { tracef("Server sends text frame success."); });
            }

            override
            void onFrame(Frame frame, WebSocketConnection connection) {
                switch (frame.getType()) {
                    case TEXT: {
                        TextFrame textFrame = cast(TextFrame) frame;
                        tracef("Server received: " ~ textFrame ~ ", " ~ textFrame.getPayloadAsUTF8());
                        assert(textFrame.getPayloadAsUTF8() == ("Hello WebSocket"));
                        latch.countDown();
                    }
                }

            }
        });
        server.start();

}

