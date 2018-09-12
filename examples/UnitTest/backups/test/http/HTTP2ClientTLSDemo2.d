module test.http;

import java.io.IOException;

import java.nio.charset.StandardCharsets;

import java.util.concurrent.ExecutionException;

import hunt.http.client.http2.ClientHttpHandler;
import hunt.http.client.http2.HttpClient;
import hunt.http.client.http2.HttpClientConnection;
import hunt.http.codec.http.model.HostPortHttpField;
import hunt.http.codec.http.model.HttpFields;
import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.model.HttpScheme;
import hunt.http.codec.http.model.HttpVersion;
import hunt.http.codec.http.model.MetaData;
import hunt.http.codec.http.stream.Http2Configuration;
import hunt.http.utils.concurrent.FuturePromise;
import hunt.container.BufferUtils;

public class Http2ClientTLSDemo2 {

	public static void main(string[] args) throws InterruptedException, ExecutionException, IOException {
		final Http2Configuration http2Configuration = new Http2Configuration();
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
						new MetaData.Request("GET", HttpScheme.HTTP, new HostPortHttpField("127.0.0.1:6655"), "/index",
								HttpVersion.HTTP_1_1, fields),
						new ClientHttpHandler.Adapter().messageComplete((req, resp, outputStream, conn) -> {
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
						new MetaData.Request("GET", HttpScheme.HTTP, new HostPortHttpField("127.0.0.1:6655"),
								"/index_1", HttpVersion.HTTP_1_1, fields),
						new ClientHttpHandler.Adapter().messageComplete((req, resp, outputStream, conn) -> {
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
