module test.http;

import java.io.IOException;

import java.nio.charset.StandardCharsets;

import java.util.concurrent.ExecutionException;

import hunt.http.client.http2.ClientHTTPHandler;
import hunt.http.client.http2.HTTP2Client;
import hunt.http.client.http2.HTTPClientConnection;
import hunt.http.codec.http.model.HostPortHttpField;
import hunt.http.codec.http.model.HttpFields;
import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.model.HttpScheme;
import hunt.http.codec.http.model.HttpVersion;
import hunt.http.codec.http.model.MetaData;
import hunt.http.codec.http.stream.HTTP2Configuration;
import hunt.http.utils.concurrent.FuturePromise;
import hunt.container.BufferUtils;

public class HTTP2ClientTLSDemo2 {

	public static void main(string[] args) throws InterruptedException, ExecutionException, IOException {
		final HTTP2Configuration http2Configuration = new HTTP2Configuration();
		http2Configuration.getTcpConfiguration().setTimeout(60 * 1000);
		http2Configuration.setSecureConnectionEnabled(true);
		HTTP2Client client = new HTTP2Client(http2Configuration);
		HTTPClientConnection httpConnection = null;
		try {

			FuturePromise<HTTPClientConnection> promise = new FuturePromise<>();
			client.connect("127.0.0.1", 6655, promise);

			httpConnection = promise.get();

			HttpFields fields = new HttpFields();
			fields.put(HttpHeader.USER_AGENT, "Hunt Client 1.0");

			if (httpConnection.getHttpVersion() == HttpVersion.HTTP_2) {
				httpConnection.send(
						new MetaData.Request("GET", HttpScheme.HTTP, new HostPortHttpField("127.0.0.1:6655"), "/index",
								HttpVersion.HTTP_1_1, fields),
						new ClientHTTPHandler.Adapter().messageComplete((req, resp, outputStream, conn) -> {
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
						new ClientHTTPHandler.Adapter().messageComplete((req, resp, outputStream, conn) -> {
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
