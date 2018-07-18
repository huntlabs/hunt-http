module test.codec.http2;

import java.io.IOException;
import hunt.container.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.Phaser;

import hunt.http.client.http2.ClientHTTPHandler;
import hunt.http.client.http2.HTTP1ClientConnection;
import hunt.http.client.http2.HTTP2Client;
import hunt.http.client.http2.HTTPClientConnection;
import hunt.http.client.http2.HTTPClientRequest;
import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.model.HttpVersion;
import hunt.http.codec.http.model.MetaData.Request;
import hunt.http.codec.http.model.MetaData.Response;
import hunt.http.codec.http.stream.HTTP2Configuration;
import hunt.http.codec.http.stream.HTTPConnection;
import hunt.http.codec.http.stream.HTTPOutputStream;
import hunt.http.utils.concurrent.FuturePromise;
import hunt.container.BufferUtils;

public class HTTP1ClientDemo3 {

	public static void main(string[] args) throws InterruptedException, ExecutionException, IOException {
		final HTTP2Configuration http2Configuration = new HTTP2Configuration();
		http2Configuration.getTcpConfiguration().setTimeout(60 * 1000);
		HTTP2Client client = new HTTP2Client(http2Configuration);

		FuturePromise<HTTPClientConnection> promise = new FuturePromise<>();
		client.connect("localhost", 6678, promise);

		HTTPConnection connection = promise.get();
		writeln(connection.getHttpVersion());

		if (connection.getHttpVersion() == HttpVersion.HTTP_1_1) {
			HTTP1ClientConnection http1ClientConnection = (HTTP1ClientConnection) connection;

			final Phaser phaser = new Phaser(2);

			// request index.html
			HTTPClientRequest request = new HTTPClientRequest("GET", "/index?version=1&test=ok");
			http1ClientConnection.send(request, new ClientHTTPHandler.Adapter() {

				override
				public bool content(ByteBuffer item, Request request, Response response, HTTPOutputStream output,
						HTTPConnection connection) {
					writeln(BufferUtils.toString(item, StandardCharsets.UTF_8));
					return false;
				}

				override
				public bool messageComplete(Request request, Response response, HTTPOutputStream output,
						HTTPConnection connection) {
					writeln(response);
					writeln(response.getFields());
					int currentPhaseNumber = phaser.arrive();
					writeln("current phase number: " ~ currentPhaseNumber);
					return true;
				}
			});
			phaser.arriveAndAwaitAdvance();

			// test 100-continue
			HTTPClientRequest post = new HTTPClientRequest("POST", "/testContinue");
			final ByteBuffer data = BufferUtils.toBuffer("client test continue 100 ", StandardCharsets.UTF_8);
			post.getFields().put(HttpHeader.CONTENT_LENGTH, string.valueOf(data.remaining()));

			http1ClientConnection.sendRequestWithContinuation(post, new ClientHTTPHandler.Adapter() {
				override
				public void continueToSendData(Request request, Response response, HTTPOutputStream outputStream,
						HTTPConnection connection) {
					try (HTTPOutputStream output = outputStream) {
						output.write(data);
					} catch (IOException e) {
						e.printStackTrace();
					}
				}

				override
				public bool content(ByteBuffer item, Request request, Response response, HTTPOutputStream output,
						HTTPConnection connection) {
					writeln(BufferUtils.toString(item, StandardCharsets.UTF_8));
					return false;
				}

				override
				public bool messageComplete(Request request, Response response, HTTPOutputStream output,
						HTTPConnection connection) {
					writeln(response);
					writeln(response.getFields());
					int currentPhaseNumber = phaser.arrive();
					writeln("current phase number: " ~ currentPhaseNumber);
					return true;
				}
			});
			phaser.arriveAndAwaitAdvance();

			writeln("demo3 request finished");
			http1ClientConnection.close();
		}
	}

}
