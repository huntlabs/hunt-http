import hunt.http.server;
import hunt.collection.ByteBuffer;
import hunt.logging.ConsoleLogger;
import hunt.util.DateTime;

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
void main(string[] args) {
    
    HttpServer server = buildServerWithWebSocket();

    server.onOpened(() {
            if(server.isTLS())
                writefln("listening on https://%s:%d", server.getHost, server.getPort);
            else 
                writefln("listening on http://%s:%d", server.getHost, server.getPort);
    })
    .onOpenFailed((e) {
        writefln("Failed to open a HttpServer, the reason: %s", e.msg);
    })
    .start();
}


HttpServer buildServerWithWebSocket() {
    HttpServer server = HttpServer.builder()
        // .setTLS("cert/server.crt", "cert/server.key", "hunt2018", "hunt2018")
        .setListener(8080, "0.0.0.0")
        .registerWebSocket("/", new class AbstractWebSocketMessageHandler {

            override void onOpen(WebSocketConnection connection) {
                connection.sendText("Resonse from / at " ~ DateTime.getTimeAsGMT());
                connection.sendText("Avaliable WebSocket endpoints: /, /ws1, /ws2.");
            }

            override void onText(string text, WebSocketConnection connection) {
                tracef("received (from %s): %s", connection.getRemoteAddress(), text); 
                connection.sendText("received at " ~ DateTime.getTimeAsGMT() ~ " : " ~ text);
            }
        })
        .addRoute("/plain*", (RoutingContext context) {
            context.responseHeader(HttpHeader.CONTENT_TYPE, MimeType.TEXT_PLAIN_VALUE);
            context.end("Hello World! " ~ DateTime.getTimeAsGMT());
        })
        .addRoute("/post", HttpMethod.POST, (RoutingContext context) {
            HttpServerRequest request = context.getRequest();
            string content = request.getStringBody();
            context.responseHeader(HttpHeader.CONTENT_TYPE, MimeType.TEXT_HTML_VALUE);
            context.end("Post: " ~ content ~ "<br><br>" ~ DateTime.getTimeAsGMT());
        })
        .registerWebSocket("/ws1", new class AbstractWebSocketMessageHandler {

            override void onOpen(WebSocketConnection connection) {
                connection.sendText("Resonse from /ws1 at " ~ DateTime.getTimeAsGMT());
            }

            override void onText(string text, WebSocketConnection connection) {
                tracef("received (from %s): %s", connection.getRemoteAddress(), text); 
                connection.sendText("received at " ~ DateTime.getTimeAsGMT() ~ " : " ~ text);
            }
        })
        .registerWebSocket("/ws2", new class AbstractWebSocketMessageHandler {

            override void onOpen(WebSocketConnection connection) {
                connection.sendText("Resonse from /ws2 at " ~ DateTime.getTimeAsGMT());
            }

            override void onText(string text, WebSocketConnection connection) {
                tracef("received (from %s): %s", connection.getRemoteAddress(), text); 
                connection.sendText("received at " ~ DateTime.getTimeAsGMT() ~ " : " ~ text);
            }
        })
        .build();
    return server;    
}
