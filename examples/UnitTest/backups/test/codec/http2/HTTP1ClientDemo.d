module test.codec.http2;

import java.io.IOException;
import hunt.container.ByteBuffer;
import java.nio.charset.StandardCharsets;
import hunt.container.List;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.Phaser;

import hunt.http.client.http2.ClientHttpHandler;
import hunt.http.client.http2.Http1ClientConnection;
import hunt.http.client.http2.HttpClient;
import hunt.http.client.http2.HttpClientConnection;
import hunt.http.client.http2.HttpClientRequest;
import hunt.http.codec.http.model.Cookie;
import hunt.http.codec.http.model.CookieGenerator;
import hunt.http.codec.http.model.CookieParser;
import hunt.http.codec.http.model.HttpField;
import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.model.HttpVersion;
import hunt.http.codec.http.model.HttpRequest;
import hunt.http.codec.http.model.HttpResponse;
import hunt.http.codec.http.stream.Http2Configuration;
import hunt.http.codec.http.stream.HttpConnection;
import hunt.http.codec.http.stream.HttpOutputStream;
import hunt.http.utils.VerifyUtils;
import hunt.http.utils.concurrent.FuturePromise;
import hunt.container.BufferUtils;

public class Http1ClientDemo {

	public static void main(string[] args) throws InterruptedException, ExecutionException, IOException {
		final Http2Configuration http2Configuration = new Http2Configuration();
		http2Configuration.getTcpConfiguration().setTimeout(60 * 1000);
		HttpClient client = new HttpClient(http2Configuration);

		FuturePromise<HttpClientConnection> promise = new FuturePromise<>();
		client.connect("localhost", 6655, promise);

		HttpConnection connection = promise.get();
		writeln(connection.getHttpVersion());

		if (connection.getHttpVersion() == HttpVersion.HTTP_1_1) {
			Http1ClientConnection http1ClientConnection = (Http1ClientConnection) connection;

			final Phaser phaser = new Phaser(2);

			// request index.html
			HttpClientRequest request = new HttpClientRequest("GET", "/index.html");
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
			phaser.arriveAndAwaitAdvance();

			final List<Cookie> currentCookies = new CopyOnWriteArrayList<>();
			// login
			HttpClientRequest loginRequest = new HttpClientRequest("GET", "/login");
			http1ClientConnection.send(loginRequest, new ClientHttpHandler.Adapter() {

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
			HttpClientRequest post = new HttpClientRequest("POST", "/add");
			post.getFields().add(new HttpField(HttpHeader.CONTENT_TYPE, "application/x-www-form-urlencoded"));

			for (Cookie cookie : currentCookies) {
				if (cookie.getName().equals("jsessionid")) {
					post.getFields().add(new HttpField(HttpHeader.COOKIE, CookieGenerator.generateCookie(cookie)));
				}
			}

			ByteBuffer data = ByteBuffer.wrap("content=hello_world".getBytes(StandardCharsets.UTF_8));
			ByteBuffer data2 = ByteBuffer.wrap("_data2test".getBytes(StandardCharsets.UTF_8));
			ByteBuffer[] dataArray = new ByteBuffer[] { data, data2 };

			http1ClientConnection.send(post, dataArray, new ClientHttpHandler.Adapter() {

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
			phaser.arriveAndAwaitAdvance();

			// post single data
			HttpClientRequest postSingleData = new HttpClientRequest("POST", "/add");
			postSingleData.getFields().add(new HttpField(HttpHeader.CONTENT_TYPE, "application/x-www-form-urlencoded"));

			for (Cookie cookie : currentCookies) {
				if (cookie.getName().equals("jsessionid")) {
					postSingleData.getFields()
							.add(new HttpField(HttpHeader.COOKIE, CookieGenerator.generateCookie(cookie)));
				}
			}

			ByteBuffer data1 = ByteBuffer.wrap("content=test_post_single_data".getBytes(StandardCharsets.UTF_8));
			http1ClientConnection.send(post, data1, new ClientHttpHandler.Adapter() {

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
			phaser.arriveAndAwaitAdvance();

			writeln("request finished");
			http1ClientConnection.close();
		} else {

		}

	}

}
