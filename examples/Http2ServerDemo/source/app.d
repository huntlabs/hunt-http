
import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.model.HttpStatus;
import hunt.http.codec.http.model.MimeTypes;

import hunt.http.server.http.SimpleHTTPServer;
import hunt.http.server.http.SimpleRequest;
import hunt.http.server.http.SimpleResponse;

import hunt.container;
import hunt.util.string;

import kiss.logger;
import std.stdio;


void main(string[] args)
{
	SimpleHTTPServer server = new SimpleHTTPServer();
        server.headerComplete( (SimpleRequest req) {
            List!(ByteBuffer) list = new ArrayList!ByteBuffer();
            req.onContent( (ByteBuffer b) {
				list.add(b);
				})
               .onContentComplete( (SimpleRequest request) {
                   string msg = BufferUtils.toString(list);
                   StringBuilder s = new StringBuilder();
                   s.append("content complete").append("\r\n")
                    .append(req.toString()).append("\r\n")
                    .append(req.getFields().toString()).append("\r\n")
                    .append(msg).append("\r\n");
                   writeln(s.toString());
                   request.put("msg", msg);
               })
               .onMessageComplete( (SimpleRequest request) {
                   SimpleResponse response = req.getResponse();
                   string path = req.getRequest().getURI().getPath();

                   response.getResponse().getFields().put(HttpHeader.CONTENT_TYPE, MimeTypes.Type.TEXT_PLAIN.asString());

                   switch (path) {
                       case "/":
                           writeln(request.getRequest().toString());
                           writeln(request.getRequest().getFields());
                           string msg = BufferUtils.toString(list);
                           writeln(msg);
						   response.write("server demo 4");
                           break;
                       case "/postData":
                           response.write("receive message -> " ~ request.get("msg"));
                           break;

                       default:
                           response.getResponse().setStatus(HttpStatus.NOT_FOUND_404);
                           response.write("resource not found");
                           break;
                   }

               });

        }).listen("0.0.0.0", 3333);
}
