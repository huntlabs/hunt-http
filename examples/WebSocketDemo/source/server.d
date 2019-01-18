
import hunt.http.codec.http.model;
import hunt.http.codec.http.stream;
import hunt.http.codec.websocket.frame;
import hunt.http.codec.websocket.model;
import hunt.http.codec.websocket.stream.WebSocketConnection;

import hunt.http.server.HttpServer;
import hunt.http.server.ServerHttpHandler;
import hunt.http.server.WebSocketHandler;


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
    HttpServer server = new HttpServer("0.0.0.0", 8080, new HttpConfiguration(), 
        new class ServerHttpHandlerAdapter {

            override
            bool messageComplete(HttpRequest request, HttpResponse response,
                                           HttpOutputStream output,
                                           HttpConnection connection) {
                return true;
            }
        }, 

        new class WebSocketHandler {
            override
            void onConnect(WebSocketConnection webSocketConnection) {
                webSocketConnection.sendText("Say hello from Hunt.HTTP.").thenAccept( 
                    (r) { tracef("Server sends text frame success."); }
                );
            }

            override
            void onFrame(Frame frame, WebSocketConnection connection) {
                FrameType type = frame.getType();
                switch (type) {
                    case FrameType.TEXT: {
                        TextFrame textFrame = cast(TextFrame) frame;
                        string msg = textFrame.getPayloadAsUTF8();
                        tracef("Server received: " ~ textFrame.toString() ~ ", " ~ msg);
                        connection.sendText(msg); // echo back
                        break;
                    }

                    default: 
                        warningf("Can't handle the frame of %s", type);
                        break;
                }

            }
        });
    
    server.start();
}

