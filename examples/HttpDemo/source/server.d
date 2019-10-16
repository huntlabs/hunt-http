import hunt.http.codec.http.model;
import hunt.http.codec.http.stream;
import hunt.http.codec.websocket.frame;
import hunt.http.codec.websocket.model;
import hunt.http.codec.websocket.stream.WebSocketConnection;

import hunt.http.server.HttpServer;
import hunt.http.server.HttpServerOptions;
import hunt.http.server.ServerHttpHandler;
import hunt.http.server.WebSocketHandler;
import hunt.http.router.RoutingContext;

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

    HttpServer server = buildServerWithoutDefaultRoute();
    
    if(server.isTLS())
	    writefln("listening on https://%s:%d", server.getHost, server.getPort);
    else 
	    writefln("listening on http://%s:%d", server.getHost, server.getPort);

    server.start();
}

HttpServer buildSimpleServer() {
    HttpServer server = HttpServer.builder()
        .setTLS("cert/server.crt", "cert/server.key", "hunt2018", "hunt2018")
        .setListener(8080, "0.0.0.0")
        .setHandler((RoutingContext context) {
            context.getResponseHeaders().put(HttpHeader.CONTENT_TYPE, MimeType.TEXT_HTML_VALUE);
            context.write(DateTime.getTimeAsGMT());
            context.write("<br>Hello World!<br>");
            context.end();
        })
        .build();  
    return server; 
}

HttpServer buildServerWithMultiRoutes() {

    HttpServer server = HttpServer.builder()
        .setTLS("cert/server.crt", "cert/server.key", "hunt2018", "hunt2018")
        .setListener(8080, "0.0.0.0")
        .addRoute("/plain*", (RoutingContext context) {
            context.getResponseHeaders().put(HttpHeader.CONTENT_TYPE, MimeType.TEXT_PLAIN_VALUE);
            context.end("Hello World! " ~ DateTime.getTimeAsGMT());
        })
        .addRoute("/testpost", HttpMethod.POST, (RoutingContext context) {
            HttpRequest request = context.getRequest();
            string content = request.getStringBody();
            warning(content);
            context.getResponseHeaders().put(HttpHeader.CONTENT_TYPE, MimeType.TEXT_PLAIN_VALUE);
            context.end("Post: " ~ content ~ ", " ~ DateTime.getTimeAsGMT());
        })
        .setHandler((RoutingContext context) {
            context.getResponseHeaders().put(HttpHeader.CONTENT_TYPE, MimeType.TEXT_HTML_VALUE);
            context.write(DateTime.getTimeAsGMT());
            context.write("<br>Hello World!<br>");
            context.end();
        })
        .build();
    return server;    
}


HttpServer buildServerWithoutDefaultRoute() {

    HttpServer server = HttpServer.builder()
        .setTLS("cert/server.crt", "cert/server.key", "hunt2018", "hunt2018")
        .setListener(8080, "0.0.0.0")
        .addRoute("/plain*", (RoutingContext context) {
            context.getResponseHeaders().put(HttpHeader.CONTENT_TYPE, MimeType.TEXT_PLAIN_VALUE);
            context.end("Hello World! " ~ DateTime.getTimeAsGMT());
        })
        .addRoute("/testpost", HttpMethod.POST, (RoutingContext context) {
            HttpRequest request = context.getRequest();
            string content = context.getStringBody();
            context.getResponseHeaders().put(HttpHeader.CONTENT_TYPE, MimeType.TEXT_PLAIN_VALUE);
            context.end("Post: " ~ content ~ ", " ~ DateTime.getTimeAsGMT());
        })
        .build();
    return server;    
}
