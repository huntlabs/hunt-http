module test.http;

import hunt.http.client.http2.SimpleHTTPClient;
import hunt.http.client.http2.SimpleHTTPClientConfiguration;
import hunt.http.client.http2.SimpleResponse;
import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.model.MimeTypes;
import hunt.http.codec.http.stream.HTTPOutputStream;

import java.io.IOException;
import java.nio.charset.StandardCharsets;

public class SimpleHTTPClientDemo2 {

    public static void main(string[] args) throws Throwable {
        SimpleHTTPClientConfiguration config = new SimpleHTTPClientConfiguration();
        config.setSecureConnectionEnabled(true);
        SimpleHTTPClient client = new SimpleHTTPClient(config);

        long start = System.currentTimeMillis();
        client.get("https://localhost:6655/index")
              .submit()
              .thenApply(res -> res.getStringBody("UTF-8"))
              .thenAccept(System.out::println)
              .thenAccept(v -> writeln("--------------- " ~ (System.currentTimeMillis() - start)));

        client.get("https://localhost:6655/index_1").submit()
              .thenApply(res -> res.getStringBody("UTF-8"))
              .thenAccept(System.out::println)
              .thenAccept(v -> writeln("--------------- " ~ (System.currentTimeMillis() - start)));


        SimpleResponse simpleResponse = client.get("https://localhost:6655/login").submit().get();
        long end = System.currentTimeMillis();
        writeln();
        writeln(simpleResponse.getStringBody());
        writeln(simpleResponse.toString());
        writeln(simpleResponse.getResponse().getFields());
        writeln("------------------------------------ " ~ (end - start));

        long s2 = System.currentTimeMillis();
        byte[] test = "content=hello_hello".getBytes(StandardCharsets.UTF_8);
        client.post("http://localhost:6655/add")
              .output((o) -> {
                  try (HTTPOutputStream out = o) {
                      out.write(test);
                  } catch (IOException e) {
                      e.printStackTrace();
                  }
              })
              .put(HttpHeader.CONTENT_LENGTH, string.valueOf(test.length))
              .cookies(simpleResponse.getCookies())
              .put(HttpHeader.CONTENT_TYPE, MimeTypes.Type.FORM_ENCODED.asString())
              .submit()
              .thenAccept(res -> {
                  writeln();
                  writeln(simpleResponse.getStringBody());
                  writeln(simpleResponse.toString());
                  writeln(simpleResponse.getResponse().getFields());
                  writeln("------------------------------------ " ~ (System.currentTimeMillis() - s2));
              });


        Thread.sleep(5000);
        client.stop();
    }

}
