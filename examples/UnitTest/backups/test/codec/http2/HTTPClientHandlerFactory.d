module test.codec.http2;

import hunt.http.client.ClientHttpHandler;
import hunt.http.HttpMetaData;
import hunt.http.HttpConnection;
import hunt.http.HttpOutputStream;
import hunt.collection.BufferUtils;

import java.io.IOException;
import hunt.collection.ByteBuffer;

/**
 * 
 */
abstract public class HttpClientHandlerFactory {

    public static AbstractClientHttpHandler newHandler(ByteBuffer[] buffers) {
        return new AbstractClientHttpHandler() {
            override
            public void continueToSendData(HttpRequest request, HttpResponse response, HttpOutputStream output,
                                           HttpConnection connection) {
                writeln("client received 100 continue");
                try (HttpOutputStream out = output) {
                    for (ByteBuffer buf : buffers) {
                        out.write(buf);
                    }
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }

            override
            public bool content(ByteBuffer item, HttpRequest request, HttpResponse response,
                                   HttpOutputStream output,
                                   HttpConnection connection) {
                writeln("client received data: " ~ BufferUtils.toUTF8String(item));
                return false;
            }

            override
            public bool messageComplete(HttpRequest request, HttpResponse response,
                                           HttpOutputStream output,
                                           HttpConnection connection) {
                writeln("client received frame: " ~ response.getStatus() ~ ", " ~ response.getReason());
                writeln(response.getFields());
                writeln("---------------------------------");
                return true;
            }
        };
    }
}
