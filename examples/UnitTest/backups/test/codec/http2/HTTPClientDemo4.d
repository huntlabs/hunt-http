module test.codec.http2;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import hunt.concurrency.ExecutionException;
import hunt.concurrency.Phaser;

import hunt.http.client.ClientHttpHandler;
import hunt.http.client.Http1ClientConnection;
import hunt.http.client.HttpClient;
import hunt.http.client.HttpClientConnection;
import hunt.http.client.HttpClientRequest;
import hunt.http.codec.http.model.HttpVersion;
import hunt.http.codec.http.stream.HttpConfiguration;
import hunt.http.codec.http.stream.HttpConnection;
import hunt.http.utils.concurrent.FuturePromise;
import hunt.collection.BufferUtils;

public class HttpClientDemo4 {

	public static void main(string[] args) throws InterruptedException, ExecutionException, IOException {
		final HttpConfiguration http2Configuration = new HttpConfiguration();
		HttpClient client = new HttpClient(http2Configuration);
		FuturePromise<HttpClientConnection> promise = new FuturePromise<>();
		client.connect("localhost", 7777, promise);
		HttpConnection connection = promise.get();
		if (connection.getHttpVersion() == HttpVersion.HTTP_1_1) {
			final Phaser phaser = new Phaser(2);
			Http1ClientConnection http1ClientConnection = (Http1ClientConnection) connection;

			HttpClientRequest request = new HttpClientRequest("GET", "/index?version=1&test=ok");
			http1ClientConnection.send(request,
					new ClientHttpHandler.Adapter().messageComplete((req, resp, outputStream, conn) -> {
						writeln("message complete: " ~ resp.getStatus() ~ "|" ~ resp.getReason());
						phaser.arrive();
						return true;
					}).content((buffer, req, resp, outputStream, conn) -> {
						writeln(BufferUtils.toString(buffer, StandardCharsets.UTF_8));
						return false;
					}).badMessage((errCode, reason, req, resp, outputStream, conn) -> {
						writeln("error: " ~ errCode ~ "|" ~ reason);
					}));
			phaser.arriveAndAwaitAdvance();
			
			HttpClientRequest request2 = new HttpClientRequest("GET", "/test");
			http1ClientConnection.send(request2,
					new ClientHttpHandler.Adapter().messageComplete((req, resp, outputStream, conn) -> {
						writeln("message complete: " ~ resp.getStatus() ~ "|" ~ resp.getReason());
						phaser.arrive();
						return true;
					}).content((buffer, req, resp, outputStream, conn) -> {
						writeln(BufferUtils.toString(buffer, StandardCharsets.UTF_8));
						return false;
					}).badMessage((errCode, reason, req, resp, outputStream, conn) -> {
						writeln("error: " ~ errCode ~ "|" ~ reason);
						phaser.arrive();
					}));
			phaser.arriveAndAwaitAdvance();
			
			writeln("demo4 request finished");
			http1ClientConnection.close();
		}
	}

}
