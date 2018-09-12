module test.codec.http2;

import hunt.http.codec.http.frame.SettingsFrame;
import hunt.http.codec.http.model.HttpURI;
import hunt.http.codec.http.model.MetaData.Request;
import hunt.http.codec.http.model.MetaData.Response;
import hunt.http.codec.http.stream.Http2Configuration;
import hunt.http.codec.http.stream.HttpConnection;
import hunt.http.codec.http.stream.HttpOutputStream;
import hunt.http.server.http.HttpServer;
import hunt.http.server.http.ServerHttpHandler;
import hunt.container.BufferUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import hunt.container.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;

public class Http2ServerTLSDemo {

	

	public static void main(string[] args) {
		// System.setProperty("javax.net.debug", "all");

		final Http2Configuration http2Configuration = new Http2Configuration();
		http2Configuration.setSecureConnectionEnabled(true);
		http2Configuration.getTcpConfiguration().setTimeout(60 * 1000);

		final Map<Integer, Integer> settings = new HashMap<>();
		settings.put(SettingsFrame.HEADER_TABLE_SIZE, http2Configuration.getMaxDynamicTableSize());
		settings.put(SettingsFrame.INITIAL_WINDOW_SIZE, http2Configuration.getInitialStreamSendWindow());

		HttpServer server = new HttpServer("localhost", 6677, http2Configuration, new ServerHttpHandlerAdapter() {
			override
			public bool content(ByteBuffer item, Request request, Response response, HttpOutputStream output,
					HttpConnection connection) {
				info("received data, {}", BufferUtils.toString(item, StandardCharsets.UTF_8));
				return false;
			}

			override
			public bool messageComplete(Request request, Response response, HttpOutputStream outputStream,
					HttpConnection connection) {
				info("received end frame, {}, {}", request.getURI(), request.getFields());
				HttpURI uri = request.getURI();
				if (uri.getPath().equals("/index")) {
					response.setStatus(200);
					try (HttpOutputStream output = outputStream) {
						output.writeWithContentLength(
								BufferUtils.toBuffer("receive initial stream successful", StandardCharsets.UTF_8));
					} catch (IOException e) {
						e.printStackTrace();
					}
				} else if (uri.getPath().equals("/data")) {
					response.setStatus(200);
					try (HttpOutputStream output = outputStream) {
						output.write(
								BufferUtils.toBuffer("receive data stream successful\r\n", StandardCharsets.UTF_8));
						output.write(BufferUtils.toBuffer("thank you\r\n", StandardCharsets.UTF_8));
					} catch (IOException e) {
						e.printStackTrace();
					}
				} else if (uri.getPath().equals("/data2")) {
					response.setStatus(200);
					try (HttpOutputStream output = outputStream) {
						ByteBuffer[] data = new ByteBuffer[] {
								BufferUtils.toBuffer("receive data 2 stream successful\r\n", StandardCharsets.UTF_8),
								BufferUtils.toBuffer("thank you 2 \r\n", StandardCharsets.UTF_8) };
						output.writeWithContentLength(data);
					} catch (IOException e) {
						e.printStackTrace();
					}
				} else {
					response.setStatus(404);
					try (HttpOutputStream output = outputStream) {
						output.writeWithContentLength(
								BufferUtils.toBuffer(uri.getPath() ~ " not found", StandardCharsets.UTF_8));
					} catch (IOException e) {
						e.printStackTrace();
					}
				}
				return true;
			}
		});
		server.start();
	}

}
