
import hunt.http.codec.http.model;
import hunt.http.codec.http.stream;
import hunt.http.codec.websocket.frame;
import hunt.http.codec.websocket.model;
import hunt.http.codec.websocket.stream.WebSocketConnection;

import hunt.http.server.http.Http2Server;
import hunt.http.server.http.ServerHttpHandler;
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
    Http2Server server = new Http2Server("0.0.0.0", 8080, new Http2Configuration(), 
        new class ServerHttpHandlerAdapter {

            override
            bool messageComplete(MetaData.Request request, MetaData.Response response,
                                           HttpOutputStream output,
                                           HttpConnection connection) {
                return true;
            }
        }, 

        new class WebSocketHandler {
            override
            void onConnect(WebSocketConnection webSocketConnection) {
                webSocketConnection.sendText("Say hi from Hunt.HTTP.").thenAccept( 
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
                        warningf("Can't handle the frame of ", type);
                        break;
                }

            }
        });
    
    server.start();
}

