module test.http;

import hunt.http.$;
import hunt.http.HttpFields;
import hunt.http.HttpHeader;
import hunt.http.server.Http2ServerBuilder;

/**
 * 
 */
public class TrailerDemo {
    public static void main(string[] args) {
        Http2ServerBuilder httpServer = $.httpsServer();
        httpServer.router().get("/trailer").handler(ctx -> {
            writeln("get request");
            ctx.put(HttpHeader.CONTENT_TYPE, "text/plain");
            ctx.getResponse().setTrailerSupplier(() -> {
                HttpFields trailer = new HttpFields();
                trailer.add("Foo", "s0");
                trailer.add("Bar", "s00");
                return trailer;
            });
            ctx.end("trailer test");
        }).listen("localhost", 3324);
    }
}
