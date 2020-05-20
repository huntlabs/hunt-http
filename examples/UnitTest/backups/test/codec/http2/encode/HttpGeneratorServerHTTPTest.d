module test.codec.http2.encode;

import hunt.http.codec.http.decode.HttpParser;
import hunt.http.codec.http.encode.HttpGenerator;
import hunt.http.HttpField;
import hunt.http.HttpFields;
import hunt.http.HttpVersion;
import hunt.http.HttpMetaData;
import hunt.io.BufferUtils;
import hunt.util.Test;
import hunt.util.runner.RunWith;
import hunt.util.runners.Parameterized;
import hunt.util.runners.Parameterized.Parameter;
import hunt.util.runners.Parameterized.Parameters;

import hunt.io.ByteBuffer;
import hunt.collection.ArrayList;
import java.util.Collection;
import java.util.EnumSet;
import hunt.collection.List;



import hunt.Assert;


public class HttpGeneratorServerHTTPTest {

    @Parameter(value = 0)
    public Run run;
    private string _content;
    private string _reason;

    
    public void testHTTP() {
        Handler handler = new Handler();

        HttpGenerator gen = new HttpGenerator();

        string t = run.toString();

        run.result.getHttpFields().clear();

        string response = run.result.build(run.httpVersion, gen, "OK\r\nTest", run.connection.val, null, run.chunks);

        HttpParser parser = new HttpParser(handler);
        parser.setHeadResponse(run.result._head);

        parser.parseNext(BufferUtils.toBuffer(response));

        if (run.result._body != null)
            assertEquals(t, run.result._body, this._content);

        if (run.httpVersion == 10)
            assertTrue(t, gen.isPersistent() || run.result._contentLength >= 0 || EnumSet.of(HttpConnectionType.CLOSE, HttpConnectionType.KEEP_ALIVE, HttpConnectionType.NONE).contains(run.connection));
        else
            assertTrue(t, gen.isPersistent() || EnumSet.of(HttpConnectionType.CLOSE, HttpConnectionType.TE_CLOSE).contains(run.connection));

        assertEquals("OK??Test", _reason);

        if (_content == null)
            assertTrue(t, run.result._body == null);
        else
            assertThat(t, run.result._contentLength, either(equalTo(_content.length)).or(equalTo(-1)));
    }

    private static class Result {
        private HttpFields _fields = new HttpFields();
        private final string _body;
        private final int _code;
        private string _connection;
        private int _contentLength;
        private string _contentType;
        private final bool _head;
        private string _other;
        private string _te;

        private Result(int code, string contentType, int contentLength, string content, bool head) {
            _code = code;
            _contentType = contentType;
            _contentLength = contentLength;
            _other = "value";
            _body = content;
            _head = head;
        }

        private string build(int version, HttpGenerator gen, string reason, string connection, string te, int nchunks) {
            string response = "";
            _connection = connection;
            _te = te;

            if (_contentType != null)
                _fields.put("Content-Type", _contentType);
            if (_contentLength >= 0)
                _fields.put("Content-Length", "" ~ _contentLength);
            if (_connection != null)
                _fields.put("Connection", _connection);
            if (_te != null)
                _fields.put("Transfer-Encoding", _te);
            if (_other != null)
                _fields.put("Other", _other);

            ByteBuffer source = _body == null ? null : BufferUtils.toBuffer(_body);
            ByteBuffer[] chunks = new ByteBuffer[nchunks];
            ByteBuffer content = null;
            int c = 0;
            if (source != null) {
                for (int i = 0; i < nchunks; i++) {
                    chunks[i] = source.duplicate();
                    chunks[i].position(i * (source.capacity() / nchunks));
                    if (i > 0)
                        chunks[i - 1].limit(chunks[i].position());
                }
                content = chunks[c++];
            }
            ByteBuffer header = null;
            ByteBuffer chunk = null;
            HttpResponse info = null;

            loop:
            while (true) {
                // if we have unwritten content
                if (source != null && content != null && content.remaining() == 0 && c < nchunks)
                    content = chunks[c++];

                // Generate
                bool last = !BufferUtils.hasContent(content);

                HttpGenerator.Result result = gen.generateResponse(info, _head, header, chunk, content, last);

                switch (result) {
                    case NEED_INFO:
                        info = new HttpResponse(HttpVersion.fromVersion(version), _code, reason, _fields, _contentLength);
                        continue;

                    case NEED_HEADER:
                        header = BufferUtils.allocate(2048);
                        continue;

                    case NEED_CHUNK:
                        chunk = BufferUtils.allocate(HttpGenerator.CHUNK_SIZE);
                        continue;

                    case NEED_CHUNK_TRAILER:
                        chunk = BufferUtils.allocate(2048);
                        continue;


                    case FLUSH:
                        if (BufferUtils.hasContent(header)) {
                            response += BufferUtils.toString(header);
                            header.position(header.limit());
                        }
                        if (BufferUtils.hasContent(chunk)) {
                            response += BufferUtils.toString(chunk);
                            chunk.position(chunk.limit());
                        }
                        if (BufferUtils.hasContent(content)) {
                            response += BufferUtils.toString(content);
                            content.position(content.limit());
                        }
                        break;

                    case CONTINUE:
                        continue;

                    case SHUTDOWN_OUT:
                        break;

                    case DONE:
                        break loop;
                }
            }
            return response;
        }

        override
        public string toString() {
            return "[" ~ _code ~ "," ~ _contentType ~ "," ~ _contentLength ~ "," ~ (_body == null ? "null" : "content") ~ "]";
        }

        public HttpFields getHttpFields() {
            return _fields;
        }
    }

    private class Handler : HttpParser.ResponseHandler {
        override
        public bool content(ByteBuffer ref) {
            if (_content == null)
                _content = "";
            _content += BufferUtils.toString(ref);
            ref.position(ref.limit());
            return false;
        }

        override
        public void earlyEOF() {
        }

        override
        public bool headerComplete() {
            _content = null;
            return false;
        }

        override
        public bool contentComplete() {
            return false;
        }

        override
        public bool messageComplete() {
            return true;
        }

        override
        public void parsedHeader(HttpField field) {
        }

        override
        public bool startResponse(HttpVersion version, int status, string reason) {
            _reason = reason;
            return false;
        }

        override
        public void badMessage(int status, string reason) {
            throw new IllegalStateException(reason);
        }

        override
        public int getHeaderCacheSize() {
            return 256;
        }
    }

    public final static string CONTENT = "The quick brown fox jumped over the lazy dog.\nNow is the time for all good men to come to the aid of the party\nThe moon is blue to a fish in love.\n";

    private static class Run {
        public static Run[] as(Result result, int ver, int chunks, HttpConnectionType connection) {
            Run run = new Run();
            run.result = result;
            run.httpVersion = ver;
            run.chunks = chunks;
            run.connection = connection;
            return new Run[]{run};
        }

        private Result result;
        private HttpConnectionType connection;
        private int httpVersion;
        private int chunks;

        override
        public string toString() {
            return string.format("result=%s,version=%d,chunks=%d,connection=%s", result, httpVersion, chunks, connection.name());
        }
    }

    private enum HttpConnectionType {
        NONE(null, 9, 10, 11),
        KEEP_ALIVE("keep-alive", 9, 10, 11),
        CLOSE("close", 9, 10, 11),
        TE_CLOSE("TE, close", 11);

        private string val;
        private int[] supportedHttpVersions;

        private HttpConnectionType(string val, int... supportedHttpVersions) {
            this.val = val;
            this.supportedHttpVersions = supportedHttpVersions;
        }

        public bool isSupportedByHttp(int version) {
            for (int supported : supportedHttpVersions) {
                if (supported == version) {
                    return true;
                }
            }
            return false;
        }
    }

    @Parameters(name = "{0}")
    public static Collection<Run[]> data() {
        Result[] results = {
                new Result(200, null, -1, null, false),
                new Result(200, null, -1, CONTENT, false),
                new Result(200, null, CONTENT.length, null, true),
                new Result(200, null, CONTENT.length, CONTENT, false),
                new Result(200, "text/html", -1, null, true),
                new Result(200, "text/html", -1, CONTENT, false),
                new Result(200, "text/html", CONTENT.length, null, true),
                new Result(200, "text/html", CONTENT.length, CONTENT, false)
        };

        List<Run[]> data = new ArrayList<>();

        // For each test result
        for (Result result : results) {
            // Loop over HTTP versions
            for (int v = 10; v <= 11; v++) {
                // Loop over chunks
                for (int chunks = 1; chunks <= 6; chunks++) {
                    // Loop over Connection values
                    for (HttpConnectionType connection : HttpConnectionType.values()) {
                        if (connection.isSupportedByHttp(v)) {
                            data.add(Run.as(result, v, chunks, connection));
                        }
                    }
                }
            }
        }
        return data;
    }
}
