module test.codec.http2;

import java.io.IOException;
import hunt.io.ByteBuffer;
import java.nio.charset.StandardCharsets;
import hunt.collection.ArrayList;
import hunt.collection.List;

import hunt.net.util.HttpURI;
import hunt.http.HttpMetaData;
import hunt.http.HttpOptions;
import hunt.http.HttpConnection;
import hunt.http.HttpOutputStream;
import hunt.http.server.HttpServer;
import hunt.http.server.ServerHttpHandler;
import hunt.http.server.ServerSessionListener;
import hunt.http.server.WebSocketHandler;
import hunt.io.BufferUtils;

public class Http1ServerChunkOutputDemo3 {

	public static void main(string[] args) {
		final HttpOptions http2Configuration = new HttpOptions();
		http2Configuration.getTcpConfiguration().setTimeout(10 * 60 * 1000);

		HttpServer server = new HttpServer("localhost", 6678, http2Configuration, new ServerSessionListener.Adapter(),
				new ServerHttpHandlerAdapter() {

					override
					public void earlyEOF(HttpRequest request, HttpResponse response, HttpOutputStream output,
										 HttpConnection connection) {
						writeln("the server connection " ~ connection.getId() ~ " is early EOF");
					}

					override
					public void badMessage(int status, string reason, HttpRequest request,
										   HttpResponse response, HttpOutputStream output, HttpConnection connection) {
						writeln("the server received a bad message, " ~ status ~ "|" ~ reason);

						try {
							connection.close();
						} catch (IOException e) {
							e.printStackTrace();
						}

					}

					override
					public bool messageComplete(HttpRequest request, HttpResponse response,
												   HttpOutputStream outputStream, HttpConnection connection) {
						HttpURI uri = request.getURI();
						writeln("current path is " ~ uri.getPath());
						writeln("current http headers are " ~ request.getFields());
						response.setStatus(200);

						List!(ByteBuffer) list = new ArrayList<>();
						list.add(BufferUtils.toBuffer("hello the server demo ", StandardCharsets.UTF_8));
						list.add(BufferUtils.toBuffer("test chunk 1 ", StandardCharsets.UTF_8));
						list.add(BufferUtils.toBuffer("test chunk 2 ", StandardCharsets.UTF_8));
						list.add(BufferUtils.toBuffer("中文的内容，哈哈 ", StandardCharsets.UTF_8));
						list.add(BufferUtils.toBuffer("靠！！！ ", StandardCharsets.UTF_8));

						try (HttpOutputStream output = outputStream) {
							for (ByteBuffer buffer : list) {
								output.write(buffer);
							}
						} catch (IOException e) {
							e.printStackTrace();
						}
						return true;
					}

				}, new WebSocketHandler() {});
		server.start();
	}

}
