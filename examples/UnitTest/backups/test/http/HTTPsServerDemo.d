module test.http;

import hunt.http.$;
import hunt.http.server.router.handler.file.StaticFileHandler;

import java.nio.file.Path;
import java.nio.file.Paths;

/**
 * 
 */
public class HTTPsServerDemo {
    public static void main(string[] args) {
        Path path = Paths.get(HTTPsServerDemo.class.getResource("/").toURI());

        $.httpsServer()
         .router().get("/").handler(ctx -> ctx.end("hello world!"))
         .router().get("/static/*")
         .handler(new StaticFileHandler(path.toAbsolutePath().toString()))
         .listen("localhost", 8081);

        $.httpServer()
         .router().get("/").handler(ctx -> ctx.end("hello world!"))
         .router().get("/static/*")
         .handler(new StaticFileHandler(path.toAbsolutePath().toString()))
         .listen("localhost", 8080);

        $.httpsClient().get("https://localhost:8081/").submit()
         .thenAccept(res -> writeln(res.getStringBody()));
    }
}
