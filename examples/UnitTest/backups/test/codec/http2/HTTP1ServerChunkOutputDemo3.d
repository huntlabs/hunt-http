module test.codec.http2;

import java.io.IOException;
import hunt.container.ByteBuffer;
import java.nio.charset.StandardCharsets;
import hunt.container.ArrayList;
import hunt.container.List;

import hunt.http.codec.http.model.HttpURI;
import hunt.http.codec.http.model.MetaData;
import hunt.http.codec.http.stream.HTTP2Configuration;
import hunt.http.codec.http.stream.HTTPConnection;
import hunt.http.codec.http.stream.HTTPOutputStream;
import hunt.http.server.http2.HTTP2Server;
import hunt.http.server.http2.ServerHTTPHandler;
import hunt.http.server.http2.ServerSessionListener;
import hunt.http.server.http2.WebSocketHandler;
import hunt.container.BufferUtils;

public class HTTP1ServerChunkOutputDemo3 {

	public static void main(string[] args) {
		final HTTP2Configuration http2Configuration = new HTTP2Configuration();
		http2Configuration.getTcpConfiguration().setTimeout(10 * 60 * 1000);

		HTTP2Server server = new HTTP2Server("localhost", 6678, http2Configuration, new ServerSessionListener.Adapter(),
				new ServerHTTPHandlerAdapter() {

					override
					public void earlyEOF(MetaData.Request request, MetaData.Response response, HTTPOutputStream output,
										 HTTPConnection connection) {
						writeln("the server connection " ~ connection.getSessionId() ~ " is early EOF");
					}

					override
					public void badMessage(int status, string reason, MetaData.Request request,
										   MetaData.Response response, HTTPOutputStream output, HTTPConnection connection) {
						writeln("the server received a bad message, " ~ status ~ "|" ~ reason);

						try {
							connection.close();
						} catch (IOException e) {
							e.printStackTrace();
						}

					}

					override
					public bool messageComplete(MetaData.Request request, MetaData.Response response,
												   HTTPOutputStream outputStream, HTTPConnection connection) {
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

						try (HTTPOutputStream output = outputStream) {
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
