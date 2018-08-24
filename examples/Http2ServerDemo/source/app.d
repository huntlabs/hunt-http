
import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.model.HttpStatus;
import hunt.http.codec.http.model.MimeTypes;

import hunt.http.server.http.SimpleHTTPServer;
import hunt.http.server.http.SimpleRequest;
import hunt.http.server.http.SimpleResponse;
import hunt.http.server.http.router.RoutingContext;

import hunt.container;
import hunt.util.string;

import kiss.logger;

import std.conv;
import std.datetime;
import std.stdio;

import hunt.http.helper;

void main(string[] args)
{
        httpsServer() // HTTPS
        // httpServer() // HTTP
         .router().get("/").handler( (RoutingContext ctx) { ctx.end("hello world!"); })
        //  .router().get("/static/*").handler(new StaticFileHandler(path.toAbsolutePath().toString()))
         .listen("0.0.0.0", 8081);
}
