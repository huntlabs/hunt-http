module test.codec.http2;

import hunt.http.client.ClientHttpHandler;
import hunt.http.client.HttpClient;
import hunt.http.client.HttpClientConnection;
import hunt.http.codec.http.model;
import hunt.http.HttpOptions;
import hunt.http.utils.concurrent.FuturePromise;

import java.io.UnsupportedEncodingException;
import hunt.io.ByteBuffer;
import hunt.concurrency.ExecutionException;

import test.codec.http2.HttpClientHandlerFactory.newHandler;

public class Http2ClientTLSDemo {

    public static void main(string[] args)
            throws InterruptedException, ExecutionException, UnsupportedEncodingException {
        final HttpOptions http2Configuration = new HttpOptions();
        http2Configuration.getTcpConfiguration().setTimeout(60 * 1000);
        http2Configuration.setSecureConnectionEnabled(true);
        HttpClient client = new HttpClient(http2Configuration);

        FuturePromise<HttpClientConnection> promise = new FuturePromise<>();
        client.connect("127.0.0.1", 6677, promise);

        final HttpClientConnection httpConnection = promise.get();

        final ByteBuffer[] buffers = new ByteBuffer[]{BufferUtils.toBuffer("hello world!".getBytes("UTF-8")),
                BufferUtils.toBuffer("big hello world!".getBytes("UTF-8"))};
        ClientHttpHandler handler = newHandler(buffers);

        // test
        HttpFields fields = new HttpFields();
        fields.put(HttpHeader.USER_AGENT, "Hunt Client 1.0");
        HttpRequest post = new HttpRequest("POST", HttpScheme.HTTP, new HostPortHttpField("127.0.0.1:6677"),
                "/data", HttpVersion.HTTP_1_1, fields);
        httpConnection.sendRequestWithContinuation(post, handler);

        HttpRequest get = new HttpRequest("GET", HttpScheme.HTTP, new HostPortHttpField("127.0.0.1:6677"),
                "/test2", HttpVersion.HTTP_1_1, new HttpFields());
        httpConnection.send(get, handler);

        HttpRequest post2 = new HttpRequest("POST", HttpScheme.HTTP, new HostPortHttpField("127.0.0.1:6677"),
                "/data", HttpVersion.HTTP_1_1, fields);
        httpConnection.send(post2, new ByteBuffer[]{BufferUtils.toBuffer("test data 2".getBytes("UTF-8")),
                BufferUtils.toBuffer("finished test data 2".getBytes("UTF-8"))}, handler);
    }


}
