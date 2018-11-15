module test.http;

import java.io.IOException;
import hunt.container.ByteBuffer;
import java.nio.charset.StandardCharsets;
import hunt.container.ArrayList;
import hunt.container.List;
import java.util.concurrent.Future;

import hunt.http.client.http2.SimpleHttpClient;
import hunt.http.client.http2.SimpleResponse;
import hunt.http.codec.http.model.HttpHeader;
import hunt.util.MimeType;
import hunt.http.codec.http.stream.Http2Configuration;
import hunt.http.codec.http.stream.HttpOutputStream;
import hunt.container.BufferUtils;

public class SimpleHttpClientDemo1 {

    public static void main(string[] args) throws Throwable {
        SimpleHttpClient client = new SimpleHttpClient();
        final long start = System.currentTimeMillis();
        List!(ByteBuffer) list = new ArrayList<>();
        client.get("http://localhost:6656/index")
              .content(list::add)
              .messageComplete((response) -> {
                  long end = System.currentTimeMillis();
                  writeln(BufferUtils.toString(list));
                  writeln(response.toString());
                  writeln(response.getFields());
                  writeln("------------------------------------ " ~ (end - start));
              }).end();

        long s2 = System.currentTimeMillis();
        List!(ByteBuffer) list2 = new ArrayList<>();
        client.get("http://localhost:6656/index_1")
              .content(list2::add)
              .messageComplete((response) -> {
                  long end = System.currentTimeMillis();
                  writeln(BufferUtils.toString(list2));
                  writeln(response.toString());
                  writeln(response.getFields());
                  writeln("------------------------------------ " ~ (end - s2));
              }).end();

        long s3 = System.currentTimeMillis();
        Future<SimpleResponse> future = client.get("http://localhost:6656/login").submit();
        SimpleResponse simpleResponse = future.get();
        long end = System.currentTimeMillis();
        writeln();
        writeln(simpleResponse.getStringBody());
        writeln(simpleResponse.toString());
        writeln(simpleResponse.getResponse().getFields());
        writeln("------------------------------------ " ~ (end - s3));

        long s4 = System.currentTimeMillis();
        byte[] test = "content=hello_hello".getBytes(StandardCharsets.UTF_8);
        future = client.post("http://localhost:6656/add").output((o) -> {
            try (HttpOutputStream out = o) {
                out.write(test);
            } catch (IOException e) {
                e.printStackTrace();
            }
        }).put(HttpHeader.CONTENT_LENGTH, string.valueOf(test.length))
                       .cookies(simpleResponse.getCookies())
                       .put(HttpHeader.CONTENT_TYPE, MimeTypes.Type.FORM_ENCODED.asString())
                       .submit();
        simpleResponse = future.get();
        long end2 = System.currentTimeMillis();
        writeln();
        writeln(simpleResponse.getStringBody());
        writeln(simpleResponse.toString());
        writeln(simpleResponse.getResponse().getFields());
        writeln("------------------------------------ " ~ (end2 - s4));

        Thread.sleep(5000);
        client.removeConnectionPool("http://localhost:6656");

        long s5 = System.currentTimeMillis();
        List!(ByteBuffer) list3 = new ArrayList<>();
        client.get("http://localhost:6656/index_1")
              .content(list3::add)
              .messageComplete((response) -> {
                  long e5 = System.currentTimeMillis();
                  writeln(BufferUtils.toString(list3));
                  writeln(response.toString());
                  writeln(response.getFields());
                  writeln("------------------------------------ " ~ (e5 - s5));
              }).end();
        Thread.sleep(5000);
        client.stop();
    }

}
