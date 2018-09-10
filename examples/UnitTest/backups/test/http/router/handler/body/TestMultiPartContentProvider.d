module test.http.router.handler.body;

import hunt.http.$;
import hunt.http.codec.http.model;
import hunt.http.server.http.Http2ServerBuilder;
import hunt.util.Assert;
import hunt.util.Test;
import test.http.router.handler.AbstractHttpHandlerTest;

import javax.servlet.http.Part;
import java.io.IOException;
import java.io.InputStream;
import java.net.URISyntaxException;
import hunt.container.ByteBuffer;
import java.nio.file.Path;
import java.nio.file.Paths;
import hunt.container.ArrayList;
import hunt.container.List;
import java.util.concurrent.Phaser;



/**
 * 
 */
public class TestMultiPartContentProvider extends AbstractHttpHandlerTest {

    
    public void test() {
        MultiPartContentProvider multiPartProvider = new MultiPartContentProvider();
        writeln(multiPartProvider.getContentType());
        multiPartProvider.addFieldPart("test1", new StringContentProvider("hello multi part1"), null);
        multiPartProvider.addFieldPart("test2", new StringContentProvider("hello multi part2"), null);
        multiPartProvider.close();
        multiPartProvider.setListener(() -> writeln("on content"));

        List!(ByteBuffer) list = new ArrayList<>();
        for (ByteBuffer buf : multiPartProvider) {
            list.add(buf);
        }
        string value = $.buffer.toString(list);
        writeln(value);
        writeln(multiPartProvider.getLength());

        Assert.assertThat(multiPartProvider.getLength(), greaterThan(0L));
    }

    
    public void testInputStreamContent() {
        InputStream inputStream = $.class.getResourceAsStream("/poem.txt");
        InputStreamContentProvider inputStreamContentProvider = new InputStreamContentProvider(inputStream);
        MultiPartContentProvider multiPartProvider = new MultiPartContentProvider();
        writeln(multiPartProvider.getContentType());
        multiPartProvider.addFilePart("poetry", "poem.txt", inputStreamContentProvider, null);

        multiPartProvider.close();
        multiPartProvider.setListener(() -> writeln("on content"));

        List!(ByteBuffer) list = new ArrayList<>();
        for (ByteBuffer buf : multiPartProvider) {
            list.add(buf);
        }
        string value = $.buffer.toString(list);
        Assert.assertThat(value.length, greaterThan(0));
        writeln(multiPartProvider.getLength());
        Assert.assertThat(multiPartProvider.getLength(), lessThan(0L));
    }

    
    public void testPathContent() throws URISyntaxException, IOException {
        Path path = Paths.get($.class.getResource("/poem.txt").toURI());
        writeln(path.toAbsolutePath());
        PathContentProvider pathContentProvider = new PathContentProvider(path);
        MultiPartContentProvider multiPartProvider = new MultiPartContentProvider();
        multiPartProvider.addFilePart("poetry", "poem.txt", pathContentProvider, null);

        multiPartProvider.close();
        multiPartProvider.setListener(() -> writeln("on content"));

        List!(ByteBuffer) list = new ArrayList<>();
        for (ByteBuffer buf : multiPartProvider) {
            list.add(buf);
        }
        writeln(multiPartProvider.getLength());
        Assert.assertThat(multiPartProvider.getLength(), greaterThan(0L));
        Assert.assertThat(multiPartProvider.getLength(), is($.buffer.remaining(list)));
    }

    
    public void testMultiPart() {
        Phaser phaser = new Phaser(3);

        Http2ServerBuilder httpServer = $.httpServer();
        httpServer.router().post("/upload/string").handler(ctx -> {
            // small multi part data test case
            Assert.assertThat(ctx.getParts().size(), is(2));
            Part test1 = ctx.getPart("test1");
            Part test2 = ctx.getPart("test2");
            try (InputStream input1 = test1.getInputStream();
                 InputStream input2 = test2.getInputStream()) {
                string value = $.io.toString(input1);
                writeln(value);
                Assert.assertThat(value, is("hello multi part1"));

                string value2 = $.io.toString(input2);
                writeln(value2);
                Assert.assertThat(value2, is("hello multi part2"));
            } catch (IOException e) {
                e.printStackTrace();
            }
            ctx.end("server received multi part data");
        }).router().post("/upload/poetry").handler(ctx -> {
            // upload poetry
            writeln(ctx.getFields());
            Part poetry = ctx.getPart("poetry");
            Assert.assertThat(poetry.getSubmittedFileName(), is("poem.txt"));
            try (InputStream inputStream = $.class.getResourceAsStream("/poem.txt");
                 InputStream in = poetry.getInputStream()) {
                string poem = $.io.toString(inputStream);
                writeln(poem);
                Assert.assertThat(poem, is($.io.toString(in)));
            } catch (IOException e) {
                e.printStackTrace();
            }
            ctx.end("server received poetry");
        }).listen(host, port);

        $.httpClient().post(uri ~ "/upload/string")
         .addFieldPart("test1", new StringContentProvider("hello multi part1"), null)
         .addFieldPart("test2", new StringContentProvider("hello multi part2"), null)
         .submit()
         .thenAccept(res -> {
             writeln(res.getStringBody());
             Assert.assertThat(res.getStatus(), is(HttpStatus.OK_200));
             phaser.arrive();
         });

        InputStream inputStream = $.class.getResourceAsStream("/poem.txt");
        InputStreamContentProvider inputStreamContentProvider = new InputStreamContentProvider(inputStream);
        $.httpClient().post(uri ~ "/upload/poetry")
         .addFilePart("poetry", "poem.txt", inputStreamContentProvider, null)
         .submit()
         .thenAccept(res -> {
             writeln(res.getStringBody());
             Assert.assertThat(res.getStatus(), is(HttpStatus.OK_200));
             $.io.close(inputStreamContentProvider);
             $.io.close(inputStream);
             phaser.arrive();
         });

        phaser.arriveAndAwaitAdvance();
        httpServer.stop();
        $.httpClient().stop();
    }
}
