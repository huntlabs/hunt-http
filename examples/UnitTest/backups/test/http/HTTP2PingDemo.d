module test.http;

import hunt.http.$;

/**
 * 
 */
public class HTTP2PingDemo {
    public static void main(string[] args) {
        $.httpsClient().get("https://www.jd.com")
         .submit()
         .thenAccept(resp -> {
             writeln(resp.getStringBody());
             writeln(resp.getHttpVersion());
         });
    }
}
