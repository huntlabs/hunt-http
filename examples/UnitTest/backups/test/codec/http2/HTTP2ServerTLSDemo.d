module test.codec.http2;

import hunt.http.codec.http.frame.SettingsFrame;
import hunt.http.codec.http.model.HttpURI;
import hunt.http.codec.http.model.MetaData.Request;
import hunt.http.codec.http.model.MetaData.Response;
import hunt.http.codec.http.stream.HTTP2Configuration;
import hunt.http.codec.http.stream.HTTPConnection;
import hunt.http.codec.http.stream.HTTPOutputStream;
import hunt.http.server.http2.HTTP2Server;
import hunt.http.server.http2.ServerHTTPHandler;
import hunt.container.BufferUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import hunt.container.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;

public class HTTP2ServerTLSDemo {

	

	public static void main(string[] args) {
		// System.setProperty("javax.net.debug", "all");

		final HTTP2Configuration http2Configuration = new HTTP2Configuration();
		http2Configuration.setSecureConnectionEnabled(true);
		http2Configuration.getTcpConfiguration().setTimeout(60 * 1000);

		final Map<Integer, Integer> settings = new HashMap<>();
		settings.put(SettingsFrame.HEADER_TABLE_SIZE, http2Configuration.getMaxDynamicTableSize());
		settings.put(SettingsFrame.INITIAL_WINDOW_SIZE, http2Configuration.getInitialStreamSendWindow());

		HTTP2Server server = new HTTP2Server("localhost", 6677, http2Configuration, new ServerHTTPHandlerAdapter() {
			override
			public bool content(ByteBuffer item, Request request, Response response, HTTPOutputStream output,
					HTTPConnection connection) {
				info("received data, {}", BufferUtils.toString(item, StandardCharsets.UTF_8));
				return false;
			}

			override
			public bool messageComplete(Request request, Response response, HTTPOutputStream outputStream,
					HTTPConnection connection) {
				info("received end frame, {}, {}", request.getURI(), request.getFields());
				HttpURI uri = request.getURI();
				if (uri.getPath().equals("/index")) {
					response.setStatus(200);
					try (HTTPOutputStream output = outputStream) {
						output.writeWithContentLength(
								BufferUtils.toBuffer("receive initial stream successful", StandardCharsets.UTF_8));
					} catch (IOException e) {
						e.printStackTrace();
					}
				} else if (uri.getPath().equals("/data")) {
					response.setStatus(200);
					try (HTTPOutputStream output = outputStream) {
						output.write(
								BufferUtils.toBuffer("receive data stream successful\r\n", StandardCharsets.UTF_8));
						output.write(BufferUtils.toBuffer("thank you\r\n", StandardCharsets.UTF_8));
					} catch (IOException e) {
						e.printStackTrace();
					}
				} else if (uri.getPath().equals("/data2")) {
					response.setStatus(200);
					try (HTTPOutputStream output = outputStream) {
						ByteBuffer[] data = new ByteBuffer[] {
								BufferUtils.toBuffer("receive data 2 stream successful\r\n", StandardCharsets.UTF_8),
								BufferUtils.toBuffer("thank you 2 \r\n", StandardCharsets.UTF_8) };
						output.writeWithContentLength(data);
					} catch (IOException e) {
						e.printStackTrace();
					}
				} else {
					response.setStatus(404);
					try (HTTPOutputStream output = outputStream) {
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
