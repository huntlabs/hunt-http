import hunt.http.server.http.SimpleHTTPServer;
import hunt.http.server.http.router.RoutingContext;

import hunt.http.helper;

import kiss.logger;

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
	string currentRootPath = dirName(thisExePath);
    writeln(currentRootPath);

    httpsServer() // For HTTPS
    .useCertificateFile(currentRootPath ~ "/cert/server.crt", currentRootPath ~ "/cert/server.key")
    // httpServer() // For HTTP
    .router().get("/").handler((RoutingContext ctx) {
        info("Resposing a HTTP request.");
        ctx.end("hello world!");
    }) //  .router().get("/static/*").handler(new StaticFileHandler(path.toAbsolutePath().toString()))
    .listen("0.0.0.0", 8081);
}
