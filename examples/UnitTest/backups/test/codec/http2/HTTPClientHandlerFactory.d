module test.codec.http2;

import hunt.http.client.http2.ClientHttpHandler;
import hunt.http.codec.http.model.MetaData;
import hunt.http.codec.http.stream.HttpConnection;
import hunt.http.codec.http.stream.HttpOutputStream;
import hunt.container.BufferUtils;

import java.io.IOException;
import hunt.container.ByteBuffer;

/**
 * 
 */
abstract public class HttpClientHandlerFactory {

    public static ClientHttpHandler.Adapter newHandler(ByteBuffer[] buffers) {
        return new ClientHttpHandler.Adapter() {
            override
            public void continueToSendData(MetaData.Request request, MetaData.Response response, HttpOutputStream output,
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
            public bool content(ByteBuffer item, MetaData.Request request, MetaData.Response response,
                                   HttpOutputStream output,
                                   HttpConnection connection) {
                writeln("client received data: " ~ BufferUtils.toUTF8String(item));
                return false;
            }

            override
            public bool messageComplete(MetaData.Request request, MetaData.Response response,
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
