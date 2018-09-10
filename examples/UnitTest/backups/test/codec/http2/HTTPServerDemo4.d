module test.codec.http2;

import java.io.IOException;
import hunt.container.ByteBuffer;
import java.nio.charset.StandardCharsets;
import hunt.container.ArrayList;
import hunt.container.List;

import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.model.HttpHeaderValue;
import hunt.http.codec.http.model.HttpURI;
import hunt.http.codec.http.stream.Http2Configuration;
import hunt.http.codec.http.stream.HttpOutputStream;
import hunt.http.server.http.Http2Server;
import hunt.http.server.http.ServerHttpHandler;
import hunt.http.utils.collection.MultiMap;
import hunt.container.BufferUtils;

public class HttpServerDemo4 {

	public static void main(string[] args) {
		int length = 2500;
		StringBuilder s = new StringBuilder(length);
		for (int i = 0; i < length; i++) {
			s.append('t');
		}
		final string data = s.toString();

		Http2Configuration http2Configuration = new Http2Configuration();
		Http2Server server = new Http2Server("localhost", 7777, http2Configuration,
				new ServerHttpHandlerAdapter().messageComplete((request, response, outputStream, connection) -> {

					HttpURI uri = request.getURI();
					// writeln("current path is " ~ uri.getPath());
					// writeln("current parameter string is " ~
					// uri.getQuery());
					// writeln("current http headers are " ~
					// request.getFields());
					MultiMap<string> parameterMap = new MultiMap<string>();
					uri.decodeQueryTo(parameterMap);
					// writeln("current parameters are " ~
					// parameterMap);

					if (uri.getPath().equals("/test")) {
						response.setStatus(200);
						response.setHttpVersion(request.getHttpVersion());
						response.getFields().add(HttpHeader.CONNECTION, HttpHeaderValue.KEEP_ALIVE);
						try (HttpOutputStream output = outputStream) {
							output.writeWithContentLength(BufferUtils.toBuffer(data, StandardCharsets.UTF_8));
						} catch (IOException e) {
							e.printStackTrace();
						}
					} else if (uri.getPath().equals("/index")) {
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
							output.writeWithContentLength(
									BufferUtils.toBuffer("receive Continue-100 successfully ", StandardCharsets.UTF_8));
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
				}));
		server.start();

	}

}
