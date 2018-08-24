import hunt.http.server.http.SimpleHTTPServer;
import hunt.http.server.http.router.RoutingContext;

import hunt.http.helper;

import kiss.logger;

import std.file;
import std.path;
import std.stdio;

void main(string[] args)
{
	string currentRootPath = dirName(thisExePath);
    writeln(currentRootPath);

    httpsServer() // For HTTPS
    .useCertificateFile(currentRootPath ~ "/cert/server.crt", currentRootPath ~ "/cert/server.key")
    // httpServer() // For HTTP
    .router().get("/").handler((RoutingContext ctx) {
        info("Request received.");
        ctx.end("hello world!");
    }) //  .router().get("/static/*").handler(new StaticFileHandler(path.toAbsolutePath().toString()))
    .listen("0.0.0.0", 8081);
}
