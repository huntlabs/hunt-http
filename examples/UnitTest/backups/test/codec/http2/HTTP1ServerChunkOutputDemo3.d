module test.codec.http2;

import java.io.IOException;
import hunt.container.ByteBuffer;
import java.nio.charset.StandardCharsets;
import hunt.container.ArrayList;
import hunt.container.List;

import hunt.http.codec.http.model.HttpURI;
import hunt.http.codec.http.model.MetaData;
import hunt.http.codec.http.stream.Http2Configuration;
import hunt.http.codec.http.stream.HttpConnection;
import hunt.http.codec.http.stream.HttpOutputStream;
import hunt.http.server.http.HttpServer;
import hunt.http.server.http.ServerHttpHandler;
import hunt.http.server.http.ServerSessionListener;
import hunt.http.server.http.WebSocketHandler;
import hunt.container.BufferUtils;

public class Http1ServerChunkOutputDemo3 {

	public static void main(string[] args) {
		final Http2Configuration http2Configuration = new Http2Configuration();
		http2Configuration.getTcpConfiguration().setTimeout(10 * 60 * 1000);

		HttpServer server = new HttpServer("localhost", 6678, http2Configuration, new ServerSessionListener.Adapter(),
				new ServerHttpHandlerAdapter() {

					override
					public void earlyEOF(MetaData.Request request, MetaData.Response response, HttpOutputStream output,
										 HttpConnection connection) {
						writeln("the server connection " ~ connection.getSessionId() ~ " is early EOF");
					}

					override
					public void badMessage(int status, string reason, MetaData.Request request,
										   MetaData.Response response, HttpOutputStream output, HttpConnection connection) {
						writeln("the server received a bad message, " ~ status ~ "|" ~ reason);

						try {
							connection.close();
						} catch (IOException e) {
							e.printStackTrace();
						}

					}

					override
					public bool messageComplete(MetaData.Request request, MetaData.Response response,
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
