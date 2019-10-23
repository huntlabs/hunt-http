import hunt.http.codec.http.model;
import hunt.http.codec.http.stream;
import hunt.http.codec.websocket.frame;
import hunt.http.codec.websocket.model;
import hunt.http.WebSocketConnection;

import hunt.http.server;

import hunt.http.routing.RoutingContext;

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
    // HttpServer server = buildServerWithForm();
    // HttpServer server = buildServerWithWebSocket();
    HttpServer server = buildServerWithSessionStore();
    
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
            context.responseHeader(HttpHeader.CONTENT_TYPE, MimeType.TEXT_HTML_VALUE);
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
            context.responseHeader(HttpHeader.CONTENT_TYPE, MimeType.TEXT_PLAIN_VALUE);
            context.end("Hello World! " ~ DateTime.getTimeAsGMT());
        })
        .addRoute("/post", HttpMethod.POST, (RoutingContext context) {
            HttpServerRequest request = context.getRequest();
            string content = request.getStringBody();
            warning(content);
            context.responseHeader(HttpHeader.CONTENT_TYPE, MimeType.TEXT_PLAIN_VALUE);
            context.end("Post: " ~ content ~ ", " ~ DateTime.getTimeAsGMT());
        })
        .setHandler((RoutingContext context) {
            context.responseHeader(HttpHeader.CONTENT_TYPE, MimeType.TEXT_HTML_VALUE);
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
            context.responseHeader(HttpHeader.CONTENT_TYPE, MimeType.TEXT_PLAIN_VALUE);
            context.end("Hello World! " ~ DateTime.getTimeAsGMT());
        })
        .addRoute("/post", HttpMethod.POST, (RoutingContext context) {
            HttpServerRequest request = context.getRequest();
            string content = request.getStringBody();
            context.responseHeader(HttpHeader.CONTENT_TYPE, MimeType.TEXT_HTML_VALUE);
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
            context.responseHeader(HttpHeader.CONTENT_TYPE, MimeType.TEXT_PLAIN_VALUE);
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

            context.responseHeader(HttpHeader.CONTENT_TYPE, MimeType.TEXT_HTML_VALUE);
            context.end("Post: " ~ content ~ "<br><br>" ~ DateTime.getTimeAsGMT());
        })
        .build();
    return server;    
}


HttpServer buildServerWithWebSocket() {
    HttpServer server = HttpServer.builder()
        .setTLS("cert/server.crt", "cert/server.key", "hunt2018", "hunt2018")
        .setListener(8080, "0.0.0.0")
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
                connection.sendText("Resonse from ws1 at " ~ DateTime.getTimeAsGMT());
            }

            override void onText(string text, WebSocketConnection connection) {
                tracef("received (from %s): %s", connection.getRemoteAddress(), text); 
                connection.sendText("received at " ~ DateTime.getTimeAsGMT() ~ " : " ~ text);
            }
        })
        .registerWebSocket("/ws2", new class AbstractWebSocketMessageHandler {

            override void onOpen(WebSocketConnection connection) {
                connection.sendText("Resonse from ws2 at " ~ DateTime.getTimeAsGMT());
            }

            override void onText(string text, WebSocketConnection connection) {
                tracef("received (from %s): %s", connection.getRemoteAddress(), text); 
                connection.sendText("received at " ~ DateTime.getTimeAsGMT() ~ " : " ~ text);
            }
        })
        .build();
    return server;    
}


HttpServer buildServerWithSessionStore() {
    // 
    HttpServer server = HttpServer.builder()
        .setTLS("cert/server.crt", "cert/server.key", "hunt2018", "hunt2018")
        .setListener(8080, "0.0.0.0")
        .enableLocalSessionStore()
        .addRoute("/plain*", (RoutingContext context) {
            context.responseHeader(HttpHeader.CONTENT_TYPE, MimeType.TEXT_PLAIN_VALUE);
            context.end("Hello World! " ~ DateTime.getTimeAsGMT());
        })
        .post("/session/:name", (RoutingContext context) {
            HttpServerRequest request = context.getRequest();
            string name = context.getRouterParameter("name");
            trace("the path param -> " ~ name);
            HttpSession session = context.getSession(true);
            tracef("new session: %s", session.isNewSession());
            session.setAttribute(name, "bar");
            session.setAttribute("age", 18);
            // 10 second later, the session will expire
            session.setMaxInactiveInterval(10);
            context.updateSession(session);
            context.end("session created");
        })
        .get("/session/:name", (RoutingContext ctx) {
            string name = ctx.getRouterParameter("name");
            HttpSession session = ctx.getSession();
            ctx.responseHeader(HttpHeader.CONTENT_TYPE, MimeType.TEXT_HTML_VALUE);
            if (session !is null) {
                ctx.write("session value is " ~ session.getAttributeAs!string(name));
                ctx.end("<br>session age is " ~ session.getAttribute("age").toString());
            } else {
                ctx.end("session is invalid");
            }
        })
        .build();
    return server;    
}