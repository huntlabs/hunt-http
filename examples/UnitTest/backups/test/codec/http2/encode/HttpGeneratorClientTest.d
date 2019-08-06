module test.codec.http2.encode;

import hunt.http.codec.http.encode.HttpGenerator;
import hunt.http.codec.http.model.HttpFields;
import hunt.net.util.HttpURI;
import hunt.http.HttpVersion;
import hunt.http.codec.http.model.MetaData;
import hunt.collection.BufferUtils;

import hunt.Assert;
import hunt.util.Test;

import hunt.collection.ByteBuffer;

import hunt.Assert.assertEquals;

public class HttpGeneratorClientTest {
    public final static string[] connect = {null, "keep-alive", "close"};

    class Info extends HttpRequest {
        Info(string method, string uri) {
            super(method, new HttpURI(uri), HttpVersion.HTTP_1_1, new HttpFields(), -1);
        }

        public Info(string method, string uri, int contentLength) {
            super(method, new HttpURI(uri), HttpVersion.HTTP_1_1, new HttpFields(), contentLength);
        }
    }

    
    public void testGETRequestNoContent() {
        ByteBuffer header = BufferUtils.allocate(2048);
        HttpGenerator gen = new HttpGenerator();

        HttpGenerator.Result result = gen.generateRequest(null, null, null, null, true);
        Assert.assertEquals(HttpGenerator.Result.NEED_INFO, result);
        Assert.assertEquals(HttpGenerator.State.START, gen.getState());

        Info info = new Info("GET", "/index.html");
        info.getFields().add("Host", "something");
        info.getFields().add("User-Agent", "test");
        Assert.assertTrue(!gen.isChunking());

        result = gen.generateRequest(info, null, null, null, true);
        Assert.assertEquals(HttpGenerator.Result.NEED_HEADER, result);
        Assert.assertEquals(HttpGenerator.State.START, gen.getState());

        result = gen.generateRequest(info, header, null, null, true);
        Assert.assertEquals(HttpGenerator.Result.FLUSH, result);
        Assert.assertEquals(HttpGenerator.State.COMPLETING, gen.getState());
        Assert.assertTrue(!gen.isChunking());
        string out = BufferUtils.toString(header);
        BufferUtils.clear(header);

        result = gen.generateResponse(null, false, null, null, null, false);
        Assert.assertEquals(HttpGenerator.Result.DONE, result);
        Assert.assertEquals(HttpGenerator.State.END, gen.getState());
        Assert.assertTrue(!gen.isChunking());

        Assert.assertEquals(0, gen.getContentPrepared());
        Assert.assertThat(out, Matchers.containsString("GET /index.html HTTP/1.1"));
        Assert.assertThat(out, Matchers.not(Matchers.containsString("Content-Length")));
    }

    
    public void testPOSTRequestNoContent() {
        ByteBuffer header = BufferUtils.allocate(2048);
        HttpGenerator gen = new HttpGenerator();

        HttpGenerator.Result
                result = gen.generateRequest(null, null, null, null, true);
        Assert.assertEquals(HttpGenerator.Result.NEED_INFO, result);
        Assert.assertEquals(HttpGenerator.State.START, gen.getState());

        Info info = new Info("POST", "/index.html");
        info.getFields().add("Host", "something");
        info.getFields().add("User-Agent", "test");
        Assert.assertTrue(!gen.isChunking());

        result = gen.generateRequest(info, null, null, null, true);
        Assert.assertEquals(HttpGenerator.Result.NEED_HEADER, result);
        Assert.assertEquals(HttpGenerator.State.START, gen.getState());

        result = gen.generateRequest(info, header, null, null, true);
        Assert.assertEquals(HttpGenerator.Result.FLUSH, result);
        Assert.assertEquals(HttpGenerator.State.COMPLETING, gen.getState());
        Assert.assertTrue(!gen.isChunking());
        string out = BufferUtils.toString(header);
        BufferUtils.clear(header);

        result = gen.generateResponse(null, false, null, null, null, false);
        Assert.assertEquals(HttpGenerator.Result.DONE, result);
        Assert.assertEquals(HttpGenerator.State.END, gen.getState());
        Assert.assertTrue(!gen.isChunking());

        Assert.assertEquals(0, gen.getContentPrepared());
        Assert.assertThat(out, Matchers.containsString("POST /index.html HTTP/1.1"));
        Assert.assertThat(out, Matchers.containsString("Content-Length: 0"));
    }

    
    public void testRequestWithContent() {
        string out;
        ByteBuffer header = BufferUtils.allocate(4096);
        ByteBuffer content0 = BufferUtils.toBuffer("Hello World. The quick brown fox jumped over the lazy dog.");
        HttpGenerator gen = new HttpGenerator();

        HttpGenerator.Result
                result = gen.generateRequest(null, null, null, content0, true);
        Assert.assertEquals(HttpGenerator.Result.NEED_INFO, result);
        Assert.assertEquals(HttpGenerator.State.START, gen.getState());

        Info info = new Info("POST", "/index.html");
        info.getFields().add("Host", "something");
        info.getFields().add("User-Agent", "test");

        result = gen.generateRequest(info, null, null, content0, true);
        Assert.assertEquals(HttpGenerator.Result.NEED_HEADER, result);
        Assert.assertEquals(HttpGenerator.State.START, gen.getState());

        result = gen.generateRequest(info, header, null, content0, true);
        Assert.assertEquals(HttpGenerator.Result.FLUSH, result);
        Assert.assertEquals(HttpGenerator.State.COMPLETING, gen.getState());
        Assert.assertTrue(!gen.isChunking());
        out = BufferUtils.toString(header);
        BufferUtils.clear(header);
        out += BufferUtils.toString(content0);
        BufferUtils.clear(content0);

        result = gen.generateResponse(null, false, null, null, null, false);
        Assert.assertEquals(HttpGenerator.Result.DONE, result);
        Assert.assertEquals(HttpGenerator.State.END, gen.getState());
        Assert.assertTrue(!gen.isChunking());


        Assert.assertThat(out, Matchers.containsString("POST /index.html HTTP/1.1"));
        Assert.assertThat(out, Matchers.containsString("Host: something"));
        Assert.assertThat(out, Matchers.containsString("Content-Length: 58"));
        Assert.assertThat(out, Matchers.containsString("Hello World. The quick brown fox jumped over the lazy dog."));

        Assert.assertEquals(58, gen.getContentPrepared());
    }

    
    public void testRequestWithChunkedContent() {
        string out;
        ByteBuffer header = BufferUtils.allocate(4096);
        ByteBuffer chunk = BufferUtils.allocate(HttpGenerator.CHUNK_SIZE);
        ByteBuffer content0 = BufferUtils.toBuffer("Hello World. ");
        ByteBuffer content1 = BufferUtils.toBuffer("The quick brown fox jumped over the lazy dog.");
        HttpGenerator gen = new HttpGenerator();

        HttpGenerator.Result result = gen.generateRequest(null, null, null, content0, false);
        Assert.assertEquals(HttpGenerator.Result.NEED_INFO, result);
        Assert.assertEquals(HttpGenerator.State.START, gen.getState());

        Info info = new Info("POST", "/index.html");
        info.getFields().add("Host", "something");
        info.getFields().add("User-Agent", "test");

        result = gen.generateRequest(info, null, null, content0, false);
        Assert.assertEquals(HttpGenerator.Result.NEED_HEADER, result);
        Assert.assertEquals(HttpGenerator.State.START, gen.getState());

        result = gen.generateRequest(info, header, null, content0, false);
        Assert.assertEquals(HttpGenerator.Result.FLUSH, result);
        Assert.assertEquals(HttpGenerator.State.COMMITTED, gen.getState());
        Assert.assertTrue(gen.isChunking());
        out = BufferUtils.toString(header);
        BufferUtils.clear(header);
        out += BufferUtils.toString(content0);
        BufferUtils.clear(content0);

        result = gen.generateRequest(null, header, null, content1, false);
        Assert.assertEquals(HttpGenerator.Result.NEED_CHUNK, result);
        Assert.assertEquals(HttpGenerator.State.COMMITTED, gen.getState());

        result = gen.generateRequest(null, null, chunk, content1, false);
        Assert.assertEquals(HttpGenerator.Result.FLUSH, result);
        Assert.assertEquals(HttpGenerator.State.COMMITTED, gen.getState());
        Assert.assertTrue(gen.isChunking());
        out += BufferUtils.toString(chunk);
        BufferUtils.clear(chunk);
        out += BufferUtils.toString(content1);
        BufferUtils.clear(content1);

        result = gen.generateResponse(null, false, null, null, null, true);
        Assert.assertEquals(HttpGenerator.Result.CONTINUE, result);
        Assert.assertEquals(HttpGenerator.State.COMPLETING, gen.getState());
        Assert.assertTrue(gen.isChunking());

        result = gen.generateResponse(null, false, null, null, null, true);
        Assert.assertEquals(HttpGenerator.Result.NEED_CHUNK, result);
        Assert.assertEquals(HttpGenerator.State.COMPLETING, gen.getState());
        Assert.assertTrue(gen.isChunking());

        result = gen.generateResponse(null, false, null, chunk, null, true);
        Assert.assertEquals(HttpGenerator.Result.FLUSH, result);
        Assert.assertEquals(HttpGenerator.State.COMPLETING, gen.getState());
        out += BufferUtils.toString(chunk);
        BufferUtils.clear(chunk);
        Assert.assertTrue(!gen.isChunking());

        result = gen.generateResponse(null, false, null, chunk, null, true);
        Assert.assertEquals(HttpGenerator.Result.DONE, result);
        Assert.assertEquals(HttpGenerator.State.END, gen.getState());

        Assert.assertThat(out, Matchers.containsString("POST /index.html HTTP/1.1"));
        Assert.assertThat(out, Matchers.containsString("Host: something"));
        Assert.assertThat(out, Matchers.containsString("Transfer-Encoding: chunked"));
        Assert.assertThat(out, Matchers.containsString("\r\nD\r\nHello World. \r\n"));
        Assert.assertThat(out, Matchers.containsString("\r\n2D\r\nThe quick brown fox jumped over the lazy dog.\r\n"));
        Assert.assertThat(out, Matchers.containsString("\r\n0\r\n\r\n"));

        Assert.assertEquals(58, gen.getContentPrepared());

    }

    
    public void testTrailer() {
        string out;
        ByteBuffer header = BufferUtils.allocate(4096);
        ByteBuffer chunk = BufferUtils.allocate(HttpGenerator.CHUNK_SIZE);
        ByteBuffer trailer = BufferUtils.allocate(4096);
        ByteBuffer content0 = BufferUtils.toBuffer("Hello World. ");
        ByteBuffer content1 = BufferUtils.toBuffer("The quick brown fox jumped over the lazy dog.");
        HttpGenerator gen = new HttpGenerator();

        Info info = new Info("POST", "/index.html");
        info.getFields().add("Host", "something");
        info.getFields().add("User-Agent", "test");

        info.setTrailerSupplier(() -> {
            HttpFields t = new HttpFields();
            t.add("Foo", "1");
            t.add("Bar", "bar2");
            return t;
        });

        HttpGenerator.Result result = gen.generateRequest(info, header, null, content0, false);
        Assert.assertEquals(HttpGenerator.Result.FLUSH, result);
        Assert.assertEquals(HttpGenerator.State.COMMITTED, gen.getState());
        Assert.assertTrue(gen.isChunking());
        out = BufferUtils.toString(header);
        BufferUtils.clear(header);
        out += BufferUtils.toString(content0);
        BufferUtils.clear(content0);

        result = gen.generateRequest(null, null, chunk, content1, false);
        Assert.assertEquals(HttpGenerator.Result.FLUSH, result);
        Assert.assertEquals(HttpGenerator.State.COMMITTED, gen.getState());
        Assert.assertTrue(gen.isChunking());
        out += BufferUtils.toString(chunk);
        BufferUtils.clear(chunk);
        out += BufferUtils.toString(content1);
        BufferUtils.clear(content1);

        result = gen.generateResponse(null, false, null, null, null, true);
        Assert.assertEquals(HttpGenerator.Result.CONTINUE, result);
        Assert.assertEquals(HttpGenerator.State.COMPLETING, gen.getState());
        Assert.assertTrue(gen.isChunking());

        result = gen.generateResponse(null, false, null, null, null, true);
        Assert.assertEquals(HttpGenerator.Result.NEED_CHUNK_TRAILER, result);
        Assert.assertEquals(HttpGenerator.State.COMPLETING, gen.getState());
        Assert.assertTrue(gen.isChunking());

        result = gen.generateResponse(null, false, null, trailer, null, true);
        assertEquals(HttpGenerator.Result.FLUSH, result);
        assertEquals(HttpGenerator.State.COMPLETING, gen.getState());
        out += BufferUtils.toString(trailer);
        BufferUtils.clear(trailer);

        result = gen.generateResponse(null, false, null, null, null, true);
        Assert.assertEquals(HttpGenerator.Result.DONE, result);
        Assert.assertEquals(HttpGenerator.State.END, gen.getState());

        writeln(out);
    }

    
    public void testRequestWithKnownContent() {
        string out;
        ByteBuffer header = BufferUtils.allocate(4096);
        ByteBuffer chunk = BufferUtils.allocate(HttpGenerator.CHUNK_SIZE);
        ByteBuffer content0 = BufferUtils.toBuffer("Hello World. ");
        ByteBuffer content1 = BufferUtils.toBuffer("The quick brown fox jumped over the lazy dog.");
        HttpGenerator gen = new HttpGenerator();

        HttpGenerator.Result
                result = gen.generateRequest(null, null, null, content0, false);
        Assert.assertEquals(HttpGenerator.Result.NEED_INFO, result);
        Assert.assertEquals(HttpGenerator.State.START, gen.getState());

        Info info = new Info("POST", "/index.html", 58);
        info.getFields().add("Host", "something");
        info.getFields().add("User-Agent", "test");

        result = gen.generateRequest(info, null, null, content0, false);
        Assert.assertEquals(HttpGenerator.Result.NEED_HEADER, result);
        Assert.assertEquals(HttpGenerator.State.START, gen.getState());

        result = gen.generateRequest(info, header, null, content0, false);
        Assert.assertEquals(HttpGenerator.Result.FLUSH, result);
        Assert.assertEquals(HttpGenerator.State.COMMITTED, gen.getState());
        Assert.assertTrue(!gen.isChunking());
        out = BufferUtils.toString(header);
        BufferUtils.clear(header);
        out += BufferUtils.toString(content0);
        BufferUtils.clear(content0);

        result = gen.generateRequest(null, null, null, content1, false);
        Assert.assertEquals(HttpGenerator.Result.FLUSH, result);
        Assert.assertEquals(HttpGenerator.State.COMMITTED, gen.getState());
        Assert.assertTrue(!gen.isChunking());
        out += BufferUtils.toString(content1);
        BufferUtils.clear(content1);

        result = gen.generateResponse(null, false, null, null, null, true);
        Assert.assertEquals(HttpGenerator.Result.CONTINUE, result);
        Assert.assertEquals(HttpGenerator.State.COMPLETING, gen.getState());
        Assert.assertTrue(!gen.isChunking());

        result = gen.generateResponse(null, false, null, null, null, true);
        Assert.assertEquals(HttpGenerator.Result.DONE, result);
        Assert.assertEquals(HttpGenerator.State.END, gen.getState());
        out += BufferUtils.toString(chunk);
        BufferUtils.clear(chunk);

        Assert.assertThat(out, Matchers.containsString("POST /index.html HTTP/1.1"));
        Assert.assertThat(out, Matchers.containsString("Host: something"));
        Assert.assertThat(out, Matchers.containsString("Content-Length: 58"));
        Assert.assertThat(out, Matchers.containsString("\r\n\r\nHello World. The quick brown fox jumped over the lazy dog."));

        Assert.assertEquals(58, gen.getContentPrepared());

    }

}
