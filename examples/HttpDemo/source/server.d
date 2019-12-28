import hunt.http.codec.http.model;
import hunt.http.codec.http.stream;
import hunt.http.codec.websocket.frame;
import hunt.http.codec.websocket.model;
import hunt.http.codec.websocket.stream.WebSocketConnection;

import hunt.http.server.HttpServer;
import hunt.http.server.HttpServerOptions;
import hunt.http.server.ServerHttpHandler;
import hunt.http.server.WebSocketHandler;

import hunt.util.DateTime;
import hunt.logging;
import hunt.util.MimeType;

import std.conv;
import std.json;
import std.stdio;

/**
openssl genrsa -out ca.key 4096
openssl req -new -x509 -days 365 -key ca.key -out ca.crt
openssl genrsa -out server.key 4096
openssl req -new -key server.key -out server.csr
openssl x509 -req -days 365 -in server.csr -CA ca.crt -CAkey ca.key -set_serial 01 -out server.crt
*/


void main(string[] args) {
    version(WITH_HUNT_TRACE) {
        HttpServer server = buildTracingServer();
    } else {
        HttpServer server = buildSimpleServer();
    }

    if(server.isTLS())
	    writefln("listening on https://%s:%d", server.getHost, server.getPort);
    else 
	    writefln("listening on http://%s:%d", server.getHost, server.getPort);

    server.start();    
}

HttpServer buildSimpleServer() {
    HttpServerOptions config = new HttpServerOptions();
    config.sslCertificate = "cert/server.crt";
    config.sslPrivateKey = "cert/server.key";
    config.keystorePassword = "hunt2018";
    config.keyPassword = "hunt2018";
    config.setSecureConnectionEnabled(true);

    write(config.isSecureConnectionEnabled);


    HttpServer server = new HttpServer("0.0.0.0", 8080, config, 

        new class ServerHttpHandlerAdapter {

            override bool messageComplete(HttpRequest request, HttpResponse response,
                HttpOutputStream outputStream, HttpConnection connection) {
                scope(exit) outputStream.close();

                string path = request.getURI().getPath(); 
                // string path = "/plaintext";
                debug trace("request path: ", path);
                // debug trace(request.toString()); 
                // trace(request.getFields()); 

                HttpFields responsFields = response.getFields();
                responsFields.put(HttpHeader.SERVER, "Hunt-HTTP/1.0");
                responsFields.put(HttpHeader.DATE, DateTime.getTimeAsGMT());
                    
                switch (path) {
                    case "/plaintext": {
                        response.setStatus(HttpStatus.OK_200);
                        enum content = "Hello, World!";
                        enum contentLength = content.length.to!string();
                        responsFields.put(HttpHeader.CONTENT_TYPE, MimeType.TEXT_PLAIN.asString());
                        responsFields.put(HttpHeader.CONTENT_LENGTH, contentLength);
                        outputStream.write(content); 
                        break;
                    }

                    case "/json": {
                        response.setStatus(HttpStatus.OK_200);
                        JSONValue js;
                        js["message"] = "Hello, World!";
                        string content = js.toString();
                        string contentLength = content.length.to!string();
                        responsFields.put(HttpHeader.CONTENT_TYPE, MimeType.APPLICATION_JSON.asString());
                        responsFields.put(HttpHeader.CONTENT_LENGTH, contentLength);
                        outputStream.write(content); 

                        break;
                    }

                    default:
                        response.setStatus(HttpStatus.NOT_FOUND_404);
                        outputStream.write("Resource not found: " ~ DateTime.getTimeAsGMT());
                        break;
                }
                    
                return true;
            }
        },
        
        new class WebSocketHandler {
            override void onConnect(WebSocketConnection webSocketConnection) {
                webSocketConnection.sendText("Say hi from Hunt.HTTP.").thenAccept((r) {
                    tracef("Server sends text frame success.");
                });
            }

            override void onFrame(Frame frame, WebSocketConnection connection) {
                FrameType type = frame.getType(); 
                switch (type) {
                    case FrameType.TEXT: {
                            TextFrame textFrame = cast(TextFrame) frame; 
                            string msg = textFrame.getPayloadAsUTF8(); 
                            tracef("Server received: " ~ textFrame.toString() ~ ", " ~ msg);
                            connection.sendText(msg);  // echo back
                            break;}

                    default:
                            warningf("Can't handle the frame of ", type); break;
                }

            }
        }
    );

    return server;
}


HttpServer buildTracingServer() {
    // TODO: Tasks pending completion -@zhangxueping at 2019-12-28T12:34:30+08:00
    // 
    HttpServerOptions config = new HttpServerOptions();

    HttpServer server = new HttpServer("0.0.0.0", 8080, config, 

        new class ServerHttpHandlerAdapter {

            override bool messageComplete(HttpRequest request, HttpResponse response,
                HttpOutputStream outputStream, HttpConnection connection) {
                scope(exit) outputStream.close();

                string path = request.getURI().getPath(); 
                // string path = "/plaintext";
                debug trace("request path: ", path);
                // debug trace(request.toString()); 
                // trace(request.getFields()); 

                HttpFields responsFields = response.getFields();
                responsFields.put(HttpHeader.SERVER, "Hunt-HTTP/1.0");
                responsFields.put(HttpHeader.DATE, DateTime.getTimeAsGMT());
                    
                switch (path) {
                    case "/plaintext": {
                        response.setStatus(HttpStatus.OK_200);
                        enum content = "Hello, World!";
                        enum contentLength = content.length.to!string();
                        responsFields.put(HttpHeader.CONTENT_TYPE, MimeType.TEXT_PLAIN.asString());
                        responsFields.put(HttpHeader.CONTENT_LENGTH, contentLength);
                        outputStream.write(content); 
                        break;
                    }

                    case "/json": {
                        response.setStatus(HttpStatus.OK_200);
                        JSONValue js;
                        js["message"] = "Hello, World!";
                        string content = js.toString();
                        string contentLength = content.length.to!string();
                        responsFields.put(HttpHeader.CONTENT_TYPE, MimeType.APPLICATION_JSON.asString());
                        responsFields.put(HttpHeader.CONTENT_LENGTH, contentLength);
                        outputStream.write(content); 

                        break;
                    }

                    default:
                        response.setStatus(HttpStatus.NOT_FOUND_404);
                        outputStream.write("Resource not found: " ~ DateTime.getTimeAsGMT());
                        break;
                }
                    
                return true;
            }
        },
        
        new class WebSocketHandler {
            override void onConnect(WebSocketConnection webSocketConnection) {
                webSocketConnection.sendText("Say hi from Hunt.HTTP.").thenAccept((r) {
                    tracef("Server sends text frame success.");
                });
            }

            override void onFrame(Frame frame, WebSocketConnection connection) {
                FrameType type = frame.getType(); 
                switch (type) {
                    case FrameType.TEXT: {
                            TextFrame textFrame = cast(TextFrame) frame; 
                            string msg = textFrame.getPayloadAsUTF8(); 
                            tracef("Server received: " ~ textFrame.toString() ~ ", " ~ msg);
                            connection.sendText(msg);  // echo back
                            break;}

                    default:
                            warningf("Can't handle the frame of ", type); break;
                }

            }
        }
    );

    server.localServiceName("HttpServerDemo");

    return server;
}