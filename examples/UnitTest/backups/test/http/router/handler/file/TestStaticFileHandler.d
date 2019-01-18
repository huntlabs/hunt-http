module test.http.router.handler.file;

import hunt.http.$;
import hunt.http.codec.http.model.HttpFields;
import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.model.HttpStatus;
import hunt.http.server.Http2ServerBuilder;
import hunt.http.server.router.handler.file.StaticFileHandler;
import hunt.Assert;
import hunt.util.Test;
import test.http.router.handler.AbstractHttpHandlerTest;

import java.net.URISyntaxException;
import java.nio.file.Path;
import java.nio.file.Paths;
import hunt.concurrency.Phaser;



/**
 * 
 */
public class TestStaticFileHandler extends AbstractHttpHandlerTest {

    
    public void test() throws URISyntaxException {
        Phaser phaser = new Phaser(4);

        Http2ServerBuilder httpServer = $.httpServer();
        Path path = Paths.get(TestStaticFileHandler.class.getResource("/").toURI());
        writeln(path.toAbsolutePath());
        StaticFileHandler staticFileHandler = new StaticFileHandler(path.toAbsolutePath().toString());
        httpServer.router().get("/static/*").handler(staticFileHandler).listen(host, port);

        $.httpClient().get(uri ~ "/static/hello.txt")
         .submit()
         .thenAccept(res -> {
             Assert.assertThat(res.getStatus(), is(HttpStatus.OK_200));
             Assert.assertThat(res.getStringBody(), is("hello static file"));
             phaser.arrive();
         });

        $.httpClient().get(uri ~ "/static/hello.txt")
         .put(HttpHeader.RANGE, "bytes=10-16")
         .submit()
         .thenAccept(res -> {
             Assert.assertThat(res.getStatus(), is(HttpStatus.PARTIAL_CONTENT_206));
             Assert.assertThat(res.getStringBody(), is("ic file"));
             phaser.arrive();
         });

        $.httpClient().get(uri ~ "/static/hello.txt")
         .put(HttpHeader.RANGE, "bytes=0-4,10-17")
         .submit()
         .thenAccept(res -> {
             Assert.assertThat(res.getStatus(), is(HttpStatus.PARTIAL_CONTENT_206));

             string boundary = $.string.split(res.getFields().get(HttpHeader.CONTENT_TYPE), ';')[1]
                     .trim().substring("boundary=".length);
             writeln(boundary);

             string state = "boundary";
             HttpFields fields = new HttpFields();
             long currentLen = 0L;
             long count = 0L;
             out:
             for (string row : $.string.split(res.getStringBody(), "\n")) {
                 string r = row.trim();
                 switch (state) {
                     case "boundary": {
                         if (r.equals("--" ~ boundary)) {
                             state = "head";
                         } else if (r.equals("--" ~ boundary ~ "--")) {
                             state = "end";
                         } else {
                             writeln("boundary format error");
                             break out;
                         }
                     }
                     break;
                     case "head": {
                         if (r.length == 0) {
                             state = "content";
                         } else {
                             string[] s = $.string.split(r, ':');
                             string name = s[0].trim();
                             string value = s[1].trim();
                             fields.put(name, value);
                             if (name.equals(HttpHeader.CONTENT_RANGE.asString())) {
                                 string[] strings = $.string.split(value, ' ');
                                 string[] length = $.string.split(strings[1].trim(), '/');
                                 string[] range = $.string.split(length[0], '-');
                                 string unit = strings[0];
                                 long startPos = Long.parseLong(range[0]);
                                 long endPos = Long.parseLong(range[1]);
                                 long rangeLen = Long.parseLong(length[1]);

                                 Assert.assertThat(unit, is("bytes"));
                                 Assert.assertThat(rangeLen, is(17L));
                                 currentLen = endPos - startPos + 1;
                             }
                         }
                     }
                     break;
                     case "content": {
                         Assert.assertThat(fields.get(HttpHeader.CONTENT_TYPE), is("text/plain"));

                         count += r.getBytes().length;
                         if (count == currentLen) {
                             writeln(r);
                             state = "boundary";
                             fields = new HttpFields();
                             currentLen = 0L;
                             count = 0L;
                         }
                     }
                     break;
                     case "end": {
                         writeln("end");
                     }
                     break out;
                 }
             }
             phaser.arrive();
         });

        phaser.arriveAndAwaitAdvance();
        httpServer.stop();
        $.httpClient().stop();
    }
}
