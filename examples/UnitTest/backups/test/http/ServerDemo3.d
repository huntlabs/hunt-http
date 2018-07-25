module test.http;

import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.model.HttpStatus;
import hunt.http.codec.http.model.MimeTypes;
import hunt.http.server.http.SimpleHTTPServer;
import hunt.http.server.http.SimpleResponse;

import java.io.PrintWriter;

public class ServerDemo3 {

    public static void main(string[] args) {
        SimpleHTTPServer server = new SimpleHTTPServer();
        server.headerComplete(request -> request.messageComplete(req -> {
            SimpleResponse response = req.getResponse();
            string path = req.getRequest().getURI().getPath();

            response.getResponse().getFields().put(HttpHeader.CONTENT_TYPE, MimeTypes.Type.TEXT_PLAIN.asString());
            switch (path) {
                case "/index":
                    response.getResponse().getFields().put(HttpHeader.CONTENT_LENGTH, "11");
                    try (PrintWriter writer = response.getPrintWriter()) {
                        writer.print("hello index");
                    }
                    break;
                case "/testPost":
                    writeln(req.getRequest().toString());
                    writeln(req.getRequest().getFields());
                    writeln(req.getStringBody());
                    try (PrintWriter writer = response.getPrintWriter()) {
                        writer.print("receive post -> " ~ req.getStringBody());
                    }
                    break;
                default:
                    response.getResponse().setStatus(HttpStatus.NOT_FOUND_404);
                    try (PrintWriter writer = response.getPrintWriter()) {
                        writer.print("resource not found");
                    }
                    break;
            }
        })).listen("localhost", 3322);
    }

}
