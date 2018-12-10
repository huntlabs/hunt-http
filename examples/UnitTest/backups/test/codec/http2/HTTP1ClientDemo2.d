module test.codec.http2;

import hunt.container.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.Phaser;

import hunt.http.client.http2.ClientHttpHandler;
import hunt.http.client.http2.Http1ClientConnection;
import hunt.http.client.http2.HttpClient;
import hunt.http.client.http2.HttpClientConnection;
import hunt.http.client.http2.HttpClientRequest;
import hunt.http.codec.http.model.HttpVersion;
import hunt.http.codec.http.model.HttpRequest;
import hunt.http.codec.http.model.HttpResponse;
import hunt.http.codec.http.stream.Http2Configuration;
import hunt.http.codec.http.stream.HttpConnection;
import hunt.http.codec.http.stream.HttpOutputStream;
import hunt.http.utils.concurrent.FuturePromise;
import hunt.container.BufferUtils;

public class Http1ClientDemo2 {

	public static void main(string[] args) throws InterruptedException, ExecutionException {
		final Http2Configuration http2Configuration = new Http2Configuration();
		http2Configuration.getTcpConfiguration().setTimeout(60 * 1000);
		HttpClient client = new HttpClient(http2Configuration);

		FuturePromise<HttpClientConnection> promise = new FuturePromise<>();
		client.connect("localhost", 6655, promise);

		HttpConnection connection = promise.get();
		writeln(connection.getHttpVersion());

		if (connection.getHttpVersion() == HttpVersion.HTTP_1_1) {
			Http1ClientConnection http1ClientConnection = (Http1ClientConnection) connection;

			final Phaser phaser = new Phaser(1);

			// request index.html
			HttpClientRequest request = new HttpClientRequest("GET", "/index");
			http1ClientConnection.send(request, new ClientHttpHandler.Adapter() {

				override
				public bool content(ByteBuffer item, Request request, Response response, HttpOutputStream output,
						HttpConnection connection) {
					writeln(BufferUtils.toString(item, StandardCharsets.UTF_8));
					return false;
				}

				override
				public bool messageComplete(Request request, Response response, HttpOutputStream output,
						HttpConnection connection) {
					writeln(response);
					writeln(response.getFields());
					int currentPhaseNumber = phaser.arrive();
					writeln("current phase number: " ~ currentPhaseNumber);
					return true;
				}
			});

			phaser.awaitAdvance(0);
			writeln("demo2 request finished");
		}

	}

}
