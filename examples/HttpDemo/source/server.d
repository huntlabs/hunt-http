import hunt.http.codec.http.model;
import hunt.http.codec.http.stream;
import hunt.http.codec.websocket.frame;
import hunt.http.codec.websocket.model;
import hunt.http.codec.websocket.stream.WebSocketConnection;

import hunt.http.server;

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

    // HttpServer server = buildSimpleServer();
    // HttpServer server = buildServerWithoutDefaultRoute();
    HttpServer server = buildServerWithForm();
    
    
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
        .addRoute("/post", HttpMethod.POST, (RoutingContext context) {
            HttpServerRequest request = context.getRequest();
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
        .addRoute("/post", HttpMethod.POST, (RoutingContext context) {
            HttpServerRequest request = context.getRequest();
            string content = request.getStringBody();
            context.getResponseHeaders().put(HttpHeader.CONTENT_TYPE, MimeType.TEXT_HTML_VALUE);
            context.end("Post: " ~ content ~ "<br><br>" ~ DateTime.getTimeAsGMT());
        })
        .build();
    return server;    
}


HttpServer buildServerWithForm() {
    // http://10.1.223.62:8080/post?returnUrl=%2flogin
    // 
    HttpServer server = HttpServer.builder()
        .setTLS("cert/server.crt", "cert/server.key", "hunt2018", "hunt2018")
        .setListener(8080, "0.0.0.0")
        .addRoute("/plain*", (RoutingContext context) {
            context.getResponseHeaders().put(HttpHeader.CONTENT_TYPE, MimeType.TEXT_PLAIN_VALUE);
            context.end("Hello World! " ~ DateTime.getTimeAsGMT());
        })
        .addRoute("/post", HttpMethod.POST, (RoutingContext context) {
            HttpServerRequest request = context.getRequest();
            string content = request.getStringBody();
            string mimeType = request.getMimeType();
            warning("mimeType: ", mimeType);
            if(mimeType == "multipart/form-data") {
                foreach (Part part; request.getParts()) {
                    // MultipartForm multipart = cast(MultipartForm) part;
                    Part multipart = part;
                    warning("File: key=%s, fileName=%s, actualFile=%s, ContentType=%s, content=%s",
                        multipart.getName(), multipart.getSubmittedFileName(), 
                        multipart.getFile(), multipart.getContentType(), cast(string) multipart.getBytes());
                }
            } else if(mimeType == "application/x-www-form-urlencoded") {
                content = request.getParameterMap().toString();
            }

            context.getResponseHeaders().put(HttpHeader.CONTENT_TYPE, MimeType.TEXT_HTML_VALUE);
            context.end("Post: " ~ content ~ "<br><br>" ~ DateTime.getTimeAsGMT());
        })
        .build();
    return server;    
}