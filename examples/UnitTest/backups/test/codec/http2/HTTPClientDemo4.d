module test.codec.http2;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.Phaser;

import hunt.http.client.http2.ClientHTTPHandler;
import hunt.http.client.http2.HTTP1ClientConnection;
import hunt.http.client.http2.HTTP2Client;
import hunt.http.client.http2.HTTPClientConnection;
import hunt.http.client.http2.HTTPClientRequest;
import hunt.http.codec.http.model.HttpVersion;
import hunt.http.codec.http.stream.HTTP2Configuration;
import hunt.http.codec.http.stream.HTTPConnection;
import hunt.http.utils.concurrent.FuturePromise;
import hunt.container.BufferUtils;

public class HTTPClientDemo4 {

	public static void main(string[] args) throws InterruptedException, ExecutionException, IOException {
		final HTTP2Configuration http2Configuration = new HTTP2Configuration();
		HTTP2Client client = new HTTP2Client(http2Configuration);
		FuturePromise<HTTPClientConnection> promise = new FuturePromise<>();
		client.connect("localhost", 7777, promise);
		HTTPConnection connection = promise.get();
		if (connection.getHttpVersion() == HttpVersion.HTTP_1_1) {
			final Phaser phaser = new Phaser(2);
			HTTP1ClientConnection http1ClientConnection = (HTTP1ClientConnection) connection;

			HTTPClientRequest request = new HTTPClientRequest("GET", "/index?version=1&test=ok");
			http1ClientConnection.send(request,
					new ClientHTTPHandler.Adapter().messageComplete((req, resp, outputStream, conn) -> {
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
			
			HTTPClientRequest request2 = new HTTPClientRequest("GET", "/test");
			http1ClientConnection.send(request2,
					new ClientHTTPHandler.Adapter().messageComplete((req, resp, outputStream, conn) -> {
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
