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
import hunt.http.utils.collection.MultiMap;
import hunt.container.BufferUtils;

public class Http1ServerDemo3 {

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
					public bool content(ByteBuffer item, MetaData.Request request, MetaData.Response response,
										   HttpOutputStream output, HttpConnection connection) {
						System.out
								.println("server received data: " ~ BufferUtils.toString(item, StandardCharsets.UTF_8));
						return false;
					}

					override
					public bool accept100Continue(MetaData.Request request, MetaData.Response response,
													 HttpOutputStream output, HttpConnection connection) {
						writeln(
								"the server received a 100 continue header, the path is " ~ request.getURI().getPath());
						return false;
					}

					override
					public bool messageComplete(MetaData.Request request, MetaData.Response response,
												   HttpOutputStream outputStream, HttpConnection connection) {
						HttpURI uri = request.getURI();
						writeln("current path is " ~ uri.getPath());
						writeln("current parameter string is " ~ uri.getQuery());
						writeln("current http headers are " ~ request.getFields());
						MultiMap<string> parameterMap = new MultiMap<string>();
						uri.decodeQueryTo(parameterMap);
						writeln("current parameters are " ~ parameterMap);

						if (uri.getPath().equals("/index")) {
							response.setStatus(200);

							List!(ByteBuffer) list = new ArrayList<>();
							list.add(BufferUtils.toBuffer("hello the server demo ", StandardCharsets.UTF_8));
							list.add(BufferUtils.toBuffer("test chunk 1 ", StandardCharsets.UTF_8));
							list.add(BufferUtils.toBuffer("test chunk 2 ", StandardCharsets.UTF_8));
							list.add(BufferUtils.toBuffer("中文的内容，哈哈 ", StandardCharsets.UTF_8));
							list.add(BufferUtils.toBuffer("靠！！！ ", StandardCharsets.UTF_8));

							try (HttpOutputStream output = outputStream) {
								output.writeWithContentLength(list.toArray(BufferUtils.EMPTY_BYTE_BUFFER_ARRAY));
							} catch (IOException e) {
								e.printStackTrace();
							}
						} else if (uri.getPath().equals("/testContinue")) {
							response.setStatus(200);
							try (HttpOutputStream output = outputStream) {
								output.writeWithContentLength(BufferUtils.toBuffer("receive Continue-100 successfully ",
										StandardCharsets.UTF_8));
							} catch (IOException e) {
								e.printStackTrace();
							}
						} else {
							response.setStatus(404);
							try (HttpOutputStream output = outputStream) {
								output.writeWithContentLength(BufferUtils.toBuffer("找不到页面", StandardCharsets.UTF_8));
							} catch (IOException e) {
								e.printStackTrace();
							}
						}

						return true;
					}

				}, new WebSocketHandler() {});
		server.start();
	}

}
