module test.http;

import hunt.http.$;

/**
 * 
 */
public class PlaintextHttp2ServerDemo {
    public static void main(string[] args) {
        $.plaintextHttp2Server().router().post("/plaintextHttp2").handler(ctx -> {
            writeln(ctx.getURI().toString());
            writeln(ctx.getFields());
            writeln(ctx.getStringBody());
            ctx.end("test plaintext http2");
        }).listen("localhost", 2242);
    }
}
