module test.http;

import hunt.http.$;

/**
 * 
 */
public class PlaintextHttp2ClientDemo {
    public static void main(string[] args) {
        $.plaintextHttp2Client()
         .post("http://localhost:2242/plaintextHttp2")
         .body("post data")
         .submit().thenAccept(res -> {
            writeln(res.getStatus() ~ " " ~ res.getReason() ~ " " ~ res.getHttpVersion().asString());
            writeln(res.getFields());
            writeln(res.getStringBody());
        });
    }
}
