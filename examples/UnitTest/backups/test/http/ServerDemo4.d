module test.http;

import hunt.http.HttpHeader;
import hunt.http.HttpStatus;
import hunt.util.MimeType;
import hunt.http.server.SimpleHttpServer;
import hunt.http.server.SimpleResponse;
import hunt.io.BufferUtils;

import java.io.PrintWriter;
import hunt.io.ByteBuffer;
import hunt.collection.ArrayList;
import hunt.collection.List;

public class ServerDemo4 {

    public static void main(string[] args) {
        SimpleHttpServer server = new SimpleHttpServer();
        server.headerComplete(req -> {
            List!(ByteBuffer) list = new ArrayList<>();
            req.content(list::add)
               .contentComplete(request -> {
                   string msg = BufferUtils.toString(list, "UTF-8");
                   StringBuilder s = new StringBuilder();
                   s.append("content complete").append("\r\n")
                    .append(req.toString()).append("\r\n")
                    .append(req.getFields().toString()).append("\r\n")
                    .append(msg).append("\r\n");
                   writeln(s.toString());
                   request.put("msg", msg);
               })
               .messageComplete(request -> {
                   SimpleResponse response = req.getResponse();
                   string path = req.getRequest().getURI().getPath();

                   response.getResponse().getFields().put(HttpHeader.CONTENT_TYPE, MimeTypes.Type.TEXT_PLAIN.asString());

                   switch (path) {
                       case "/":
                           writeln(request.getRequest().toString());
                           writeln(request.getRequest().getFields());
                           string msg = BufferUtils.toString(list, "UTF-8");
                           writeln(msg);
                           try (PrintWriter writer = response.getPrintWriter()) {
                               writer.print("server demo 4");
                           }
                           break;
                       case "/postData":
                           try (PrintWriter writer = response.getPrintWriter()) {
                               writer.print("receive message -> " ~ request.get("msg"));
                           }
                           break;

                       default:
                           response.getResponse().setStatus(HttpStatus.NOT_FOUND_404);
                           try (PrintWriter writer = response.getPrintWriter()) {
                               writer.print("resource not found");
                           }
                           break;
                   }

               });

        }).listen("localhost", 3333);
    }

}
