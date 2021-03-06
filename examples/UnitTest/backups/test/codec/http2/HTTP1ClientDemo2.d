module test.codec.http2;

import hunt.io.ByteBuffer;
import java.nio.charset.StandardCharsets;
import hunt.concurrency.ExecutionException;
import hunt.concurrency.Phaser;

import hunt.http.client.ClientHttpHandler;
import hunt.http.client.Http1ClientConnection;
import hunt.http.client.HttpClient;
import hunt.http.client.HttpClientConnection;
import hunt.http.client.HttpClientRequest;
import hunt.http.HttpVersion;
import hunt.http.codec.http.model.HttpRequest;
import hunt.http.codec.http.model.HttpResponse;
import hunt.http.HttpOptions;
import hunt.http.HttpConnection;
import hunt.http.HttpOutputStream;
import hunt.http.utils.concurrent.FuturePromise;
import hunt.io.BufferUtils;

public class Http1ClientDemo2 {

	public static void main(string[] args) throws InterruptedException, ExecutionException {
		final HttpOptions http2Configuration = new HttpOptions();
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
			http1ClientConnection.send(request, new AbstractClientHttpHandler() {

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
