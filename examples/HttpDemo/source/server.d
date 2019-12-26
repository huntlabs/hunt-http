
import hunt.http.client;
import hunt.http.server;

import hunt.trace.Tracer;

import hunt.logging.ConsoleLogger;
import hunt.util.DateTime;

import std.conv;
import std.format;
import std.json;
import std.range;
import std.stdio;



void main(string[] args) {

    version(WITH_HUNT_TRACE) {
        HttpServer server = buildOpenTracingServer();
    } else {
        HttpServer server = buildSimpleServer();
    // HttpServer server = buildServerDefaultRoute();
    // HttpServer server = buildServerWithForm();
    // HttpServer server = buildServerWithTLS();
    // HttpServer server = buildServerWithUpload();
    // HttpServer server = buildServerWithWebSocket();
    // HttpServer server = buildServerWithSessionStore();
    }
    
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


HttpServer buildSimpleServer() {
    HttpServer server = HttpServer.builder()
        // .setTLS("cert/server.crt", "cert/server.key", "hunt2018", "hunt2018")
        .setListener(8080, "0.0.0.0")
        .setHandler((RoutingContext context) {
            context.responseHeader(HttpHeader.CONTENT_TYPE, MimeType.TEXT_HTML_VALUE);
            context.write(DateTime.getTimeAsGMT());
            context.write("<br>Hello World!<br>");
            context.end();
        })
        .onError((HttpServerContext context) {
            HttpServerResponse res = context.httpResponse();
            assert(res !is null);
            version(HUNT_DEBUG) warningf("badMessage: status=%d reason=%s", 
                res.getStatus(), res.getReason());
        })
        .build();  
    return server; 
}


HttpServer buildServerDefaultRoute() {
    HttpServer server = HttpServer.builder()
        // .setTLS("cert/server.crt", "cert/server.key")
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
        .resource("/files", "/home")
        .setDefaultRequest((RoutingContext ctx) {
            string content = "The resource " ~ ctx.getURI().getPath() ~ " is not found";
            string title = "404 - not found";

            ctx.responseHeader(HttpHeader.CONTENT_TYPE, "text/html");

            ctx.write("<!DOCTYPE html>")
                .write("<html>")
                .write("<head>")
                .write("<title>")
                .write(title)
                .write("</title>")
                .write("</head>")
                .write("<body>")
                .write("<h1> " ~ title ~ " </h1>")
                .write("<p>" ~ content ~ "</p>")
                .write("</body>")
                .end("</html>");
        })
        .build();
    return server;    
}


HttpServer buildServerWithMultiRoutes() {

    HttpServer server = HttpServer.builder()
        // .setTLS("cert/server.crt", "cert/server.key", "hunt2018", "hunt2018")
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


HttpServer buildServerWithTLS() {

    HttpServer server = HttpServer.builder()
        // .setCaCert("cert/ca.crt", "hunt2019")
        .setTLS("cert/server.crt", "cert/server.key", "hunt2018", "hunt2018")
        // .requiresClientAuth()
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

HttpServer buildServerWithUpload() {
    // http://10.1.223.62:8080/post?returnUrl=%2flogin
    // 
    HttpServer server = HttpServer.builder()
        // .setTLS("cert/server.crt", "cert/server.key", "hunt2018", "hunt2018")
        .setListener(8080, "0.0.0.0")
        .addRoute("/plain*", (RoutingContext context) {
            context.responseHeader(HttpHeader.CONTENT_TYPE, MimeType.TEXT_PLAIN_VALUE);
            context.end("Hello World! " ~ DateTime.getTimeAsGMT());
        })
        .addRoute("/upload/string", HttpMethod.POST, (RoutingContext context) {
            HttpServerRequest request = context.getRequest();
            string content;
            content = request.getStringBody();
            string mimeType = request.getMimeType();
            warning("mimeType: ", mimeType);
            if(mimeType == "multipart/form-data") {
                try {
                    // trace(content);
                    // tracef("%(%02X %)", cast(byte[])content);
                    Part[] parts = request.getParts();
                    foreach (Part part; parts) {
                        // MultipartForm multipart = cast(MultipartForm) part;
                        Part multipart = part;
                        warningf("File: key=%s, fileName=%s, actualFile=%s, ContentType=%s, content=%s",
                            multipart.getName(), multipart.getSubmittedFileName(), 
                            multipart.getFile(), multipart.getContentType(), cast(string) multipart.getBytes());
                    }
                } catch (Exception e) {
                    warning("get multi part exception: ", e.msg);
                    version(HUNT_HTTP_DEBUG) warning(e);
                }
            } else if(mimeType == "application/x-www-form-urlencoded") {
                // string content = request.getStringBody();
                content = request.getParameterMap().toString();
            }

            context.responseHeader(HttpHeader.CONTENT_TYPE, MimeType.TEXT_HTML_VALUE);
            context.end("multipart data received.<br><br>" ~ DateTime.getTimeAsGMT());
        })
        .addRoute("/upload/file", HttpMethod.POST, (RoutingContext context) {
            HttpServerRequest request = context.getRequest();
            // string content = request.getStringBody();
            string mimeType = request.getMimeType();
            warning("mimeType: ", mimeType);
            // info(content);
            if(mimeType == "multipart/form-data") {
                Part[] parts = request.getParts();
                context.write("File uploaded!<br>\n");
                foreach (Part part; request.getParts()) {
                    // MultipartForm multipart = cast(MultipartForm) part;
                    string str = format("%s<br>\n", part.toString());
                    context.write(str);

                    string fileName = part.getSubmittedFileName();

                    warningf("File: key=%s, fileName=%s, actualFile=%s, ContentType=%s",
                        part.getName(), fileName, 
                        part.getFile(), part.getContentType());
                    
                    part.flush(); // Save the content to a temp file 

                    // Write to a specified file.
                    if(!fileName.empty()) { // It's a file part, so will be saved.
                        string savedFile = "file-" ~ DateTime.currentTimeMillis.to!string() ~ "-" ~ fileName;
                        warning("File saved to: ", savedFile);
                        part.writeTo(savedFile);
                        str = format("savedFile: %s<br><br>\n", savedFile);
                        context.write(str);
                    }
                }
                
                context.responseHeader(HttpHeader.CONTENT_TYPE, MimeType.TEXT_HTML_VALUE);
                context.end(DateTime.getTimeAsGMT());
            } else {
                string content = request.getStringBody();
                content = request.getParameterMap().toString();
                context.responseHeader(HttpHeader.CONTENT_TYPE, MimeType.TEXT_HTML_VALUE);
                context.end("wrong data format: " ~ mimeType ~ ",  "  ~ DateTime.getTimeAsGMT());
            }
        })
        // .maxRequestSize(256) // test maxRequestSize
        .build();
    return server;    
}


HttpServer buildServerWithWebSocket() {
    HttpServer server = HttpServer.builder()
        // .setTLS("cert/server.crt", "cert/server.key", "hunt2018", "hunt2018")
        .setListener(8080, "0.0.0.0")
        .websocket("/", new class AbstractWebSocketMessageHandler {

            override void onOpen(WebSocketConnection connection) {
                connection.sendText("Resonse from / at " ~ DateTime.getTimeAsGMT());
                connection.sendText("Avaliable WebSocket endpoints: /, /ws1, /ws2.");
            }

            override void onText(WebSocketConnection connection, string text) {
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
        .websocket("/ws1", new class AbstractWebSocketMessageHandler {

            override void onOpen(WebSocketConnection connection) {
                connection.sendText("Resonse from /ws1 at " ~ DateTime.getTimeAsGMT());
            }

            override void onText(WebSocketConnection connection, string text) {
                tracef("received (from %s): %s", connection.getRemoteAddress(), text); 
                connection.sendText("received at " ~ DateTime.getTimeAsGMT() ~ " : " ~ text);
            }
        })
        .websocket("/ws2", new class AbstractWebSocketMessageHandler {

            override void onOpen(WebSocketConnection connection) {
                connection.sendText("Resonse from /ws2 at " ~ DateTime.getTimeAsGMT());
            }

            override void onText(WebSocketConnection connection, string text) {
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
        // .setTLS("cert/server.crt", "cert/server.key", "hunt2018", "hunt2018")
        .setListener(8080, "0.0.0.0")
        .enableLocalSessionStore()
        .addRoute("/plain*", (RoutingContext context) {
            context.responseHeader(HttpHeader.CONTENT_TYPE, MimeType.TEXT_PLAIN_VALUE);
            context.end("Hello World! " ~ DateTime.getTimeAsGMT());
        })
        .onPost("/session/:name", (RoutingContext context) {
            HttpServerRequest request = context.getRequest();
            string name = context.getRouterParameter("name");
            trace("the path param -> " ~ name);
            string age = context.getParameter("age");
            warning("age: ", age);

            HttpSession session = context.getSession(true);

            tracef("new session: %s", session.isNewSession());
            session.setAttribute(name, "bar");
            session.setAttribute("age", age);

            // 10 seconds later, the session will expire
            session.setMaxInactiveInterval(10);
            context.updateSession(session);
            context.end("Session created. Expired in 10 seconds.");
        })
        .onGet("/session/:name", (RoutingContext ctx) {
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

version(WITH_HUNT_TRACE) {
    HttpServer buildOpenTracingServer() {
        
        import hunt.trace.HttpSender;
        string endpoint = "http://10.1.222.120:9411/api/v2/spans";
        httpSender().endpoint(endpoint);


        HttpServer server = HttpServer.builder()
            .setListener(8080, "0.0.0.0")
            .localServiceName("HttpServerDemo")
            .setHandler((RoutingContext context) {

                context.responseHeader(HttpHeader.CONTENT_TYPE, MimeType.TEXT_HTML_VALUE);
                context.write(DateTime.getTimeAsGMT());
                
                string url = "http://10.1.222.120:801/index.html";
                HttpClient client = new HttpClient();

                RequestBuilder requestBuilder = new RequestBuilder()
                        .url(url)
                        .localServiceName("HttpServerDemo");

                HttpServerRequest serverRequest = context.getRequest();
                
                Object obj = serverRequest.getAttachment();
                if(obj !is null) {
                    Tracer tracer = cast(Tracer)obj;
                    if(tracer !is null) {
                        requestBuilder.withTracer(tracer);
                    } else {
                        // warning("Attachment conflict: ", typeid(obj));
                        // context.write(format("<br>Attachment conflict: %s<br>", typeid(obj)));
                        // context.end();
                        // return;
                    }
                } else {
                    warning("No tracer found");
                }

                Request request = requestBuilder.build();
                Response response = client.newCall(request).execute();

                if (response !is null) {
                    warningf("status code: %d", response.getStatus());
                    // if(response.haveBody())
                    //  trace(response.getBody().asString());
                } else {
                    warning("no response");
                }
                context.write("<br>Hello World!<br>");
                context.end();
            })
            .onError((HttpServerContext context) {
                HttpServerResponse res = context.httpResponse();
                assert(res !is null);
                version(HUNT_DEBUG) warningf("badMessage: status=%d reason=%s", 
                    res.getStatus(), res.getReason());
            })
            .build();  
        return server; 
    }
}