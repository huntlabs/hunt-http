module test.codec.http2;

import java.io.IOException;
import hunt.container.ByteBuffer;
import java.nio.charset.StandardCharsets;
import hunt.container.List;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.Phaser;

import hunt.http.client.http2.ClientHTTPHandler;
import hunt.http.client.http2.HTTP1ClientConnection;
import hunt.http.client.http2.HTTP2Client;
import hunt.http.client.http2.HTTPClientConnection;
import hunt.http.client.http2.HTTPClientRequest;
import hunt.http.codec.http.model.Cookie;
import hunt.http.codec.http.model.CookieGenerator;
import hunt.http.codec.http.model.CookieParser;
import hunt.http.codec.http.model.HttpField;
import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.model.HttpVersion;
import hunt.http.codec.http.model.MetaData.Request;
import hunt.http.codec.http.model.MetaData.Response;
import hunt.http.codec.http.stream.HTTP2Configuration;
import hunt.http.codec.http.stream.HTTPConnection;
import hunt.http.codec.http.stream.HTTPOutputStream;
import hunt.http.utils.VerifyUtils;
import hunt.http.utils.concurrent.FuturePromise;
import hunt.container.BufferUtils;

public class HTTP1ClientDemo {

	public static void main(string[] args) throws InterruptedException, ExecutionException, IOException {
		final HTTP2Configuration http2Configuration = new HTTP2Configuration();
		http2Configuration.getTcpConfiguration().setTimeout(60 * 1000);
		HTTP2Client client = new HTTP2Client(http2Configuration);

		FuturePromise<HTTPClientConnection> promise = new FuturePromise<>();
		client.connect("localhost", 6655, promise);

		HTTPConnection connection = promise.get();
		writeln(connection.getHttpVersion());

		if (connection.getHttpVersion() == HttpVersion.HTTP_1_1) {
			HTTP1ClientConnection http1ClientConnection = (HTTP1ClientConnection) connection;

			final Phaser phaser = new Phaser(2);

			// request index.html
			HTTPClientRequest request = new HTTPClientRequest("GET", "/index.html");
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

			final List<Cookie> currentCookies = new CopyOnWriteArrayList<>();
			// login
			HTTPClientRequest loginRequest = new HTTPClientRequest("GET", "/login");
			http1ClientConnection.send(loginRequest, new ClientHTTPHandler.Adapter() {

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
					string cookieString = response.getFields().get(HttpHeader.SET_COOKIE);
					if (VerifyUtils.isNotEmpty(cookieString)) {
						Cookie cookie = CookieParser.parseSetCookie(cookieString);
						currentCookies.add(cookie);
					}

					int currentPhaseNumber = phaser.arrive();
					writeln("current phase number: " ~ currentPhaseNumber);
					return true;
				}
			});
			phaser.arriveAndAwaitAdvance();

			writeln("current cookies : " ~ currentCookies);
			// post data
			HTTPClientRequest post = new HTTPClientRequest("POST", "/add");
			post.getFields().add(new HttpField(HttpHeader.CONTENT_TYPE, "application/x-www-form-urlencoded"));

			for (Cookie cookie : currentCookies) {
				if (cookie.getName().equals("jsessionid")) {
					post.getFields().add(new HttpField(HttpHeader.COOKIE, CookieGenerator.generateCookie(cookie)));
				}
			}

			ByteBuffer data = ByteBuffer.wrap("content=hello_world".getBytes(StandardCharsets.UTF_8));
			ByteBuffer data2 = ByteBuffer.wrap("_data2test".getBytes(StandardCharsets.UTF_8));
			ByteBuffer[] dataArray = new ByteBuffer[] { data, data2 };

			http1ClientConnection.send(post, dataArray, new ClientHTTPHandler.Adapter() {

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

			// post single data
			HTTPClientRequest postSingleData = new HTTPClientRequest("POST", "/add");
			postSingleData.getFields().add(new HttpField(HttpHeader.CONTENT_TYPE, "application/x-www-form-urlencoded"));

			for (Cookie cookie : currentCookies) {
				if (cookie.getName().equals("jsessionid")) {
					postSingleData.getFields()
							.add(new HttpField(HttpHeader.COOKIE, CookieGenerator.generateCookie(cookie)));
				}
			}

			ByteBuffer data1 = ByteBuffer.wrap("content=test_post_single_data".getBytes(StandardCharsets.UTF_8));
			http1ClientConnection.send(post, data1, new ClientHTTPHandler.Adapter() {

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

			writeln("request finished");
			http1ClientConnection.close();
		} else {

		}

	}

}
