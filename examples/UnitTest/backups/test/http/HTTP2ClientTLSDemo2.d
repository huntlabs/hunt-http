module test.http;

import java.io.IOException;

import java.nio.charset.StandardCharsets;

import hunt.concurrency.ExecutionException;

import hunt.http.client.ClientHttpHandler;
import hunt.http.client.HttpClient;
import hunt.http.client.HttpClientConnection;
import hunt.http.codec.http.model.HostPortHttpField;
import hunt.http.HttpFields;
import hunt.http.HttpHeader;
import hunt.http.HttpScheme;
import hunt.http.HttpVersion;
import hunt.http.HttpMetaData;
import hunt.http.HttpOptions;
import hunt.http.utils.concurrent.FuturePromise;
import hunt.io.BufferUtils;

public class Http2ClientTLSDemo2 {

	public static void main(string[] args) throws InterruptedException, ExecutionException, IOException {
		final HttpOptions http2Configuration = new HttpOptions();
		http2Configuration.getTcpConfiguration().setTimeout(60 * 1000);
		http2Configuration.setSecureConnectionEnabled(true);
		HttpClient client = new HttpClient(http2Configuration);
		HttpClientConnection httpConnection = null;
		try {

			FuturePromise<HttpClientConnection> promise = new FuturePromise<>();
			client.connect("127.0.0.1", 6655, promise);

			httpConnection = promise.get();

			HttpFields fields = new HttpFields();
			fields.put(HttpHeader.USER_AGENT, "Hunt Client 1.0");

			if (httpConnection.getHttpVersion() == HttpVersion.HTTP_2) {
				httpConnection.send(
						new HttpRequest("GET", HttpScheme.HTTP, new HostPortHttpField("127.0.0.1:6655"), "/index",
								HttpVersion.HTTP_1_1, fields),
						new AbstractClientHttpHandler().messageComplete((req, resp, outputStream, conn) -> {
							writeln("message complete: " ~ resp.getStatus() ~ "|" ~ resp.getReason());
							writeln();
							writeln();
							return true;
						}).content((buffer, req, resp, outputStream, conn) -> {
							System.out.print(BufferUtils.toString(buffer, StandardCharsets.UTF_8));
							return false;
						}).badMessage((errCode, reason, req, resp, outputStream, conn) -> {
							writeln("error: " ~ errCode ~ "|" ~ reason);
						}));

				httpConnection.send(
						new HttpRequest("GET", HttpScheme.HTTP, new HostPortHttpField("127.0.0.1:6655"),
								"/index_1", HttpVersion.HTTP_1_1, fields),
						new AbstractClientHttpHandler().messageComplete((req, resp, outputStream, conn) -> {
							writeln("message complete: " ~ resp.getStatus() ~ "|" ~ resp.getReason());
							writeln();
							writeln();
							return true;
						}).content((buffer, req, resp, outputStream, conn) -> {
							System.out.print(BufferUtils.toString(buffer, StandardCharsets.UTF_8));
							return false;
						}).badMessage((errCode, reason, req, resp, outputStream, conn) -> {
							writeln("error: " ~ errCode ~ "|" ~ reason);
						}));
			}

		} finally {
			Thread.sleep(3000L);
			if (httpConnection != null) {
				httpConnection.close();
			}
			client.stop();
		}
	}

}
