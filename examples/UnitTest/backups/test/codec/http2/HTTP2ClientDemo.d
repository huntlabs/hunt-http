module test.codec.http2;

import hunt.http.client.http2.ClientHttp2SessionListener;
import hunt.http.client.http2.Http2Client;
import hunt.http.client.http2.Http2ClientConnection;
import hunt.http.client.http2.HttpClientConnection;
import hunt.http.codec.http.frame;
import hunt.http.codec.http.model;
import hunt.http.codec.http.stream.Http2Configuration;
import hunt.http.codec.http.stream.HttpConnection;
import hunt.http.codec.http.stream.Session;
import hunt.http.codec.http.stream.Session.Listener;
import hunt.http.codec.http.stream.Stream;
import hunt.util.functional;
import hunt.http.utils.concurrent.FuturePromise;
import hunt.container.BufferUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.UnsupportedEncodingException;
import hunt.container.ByteBuffer;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ExecutionException;

public class Http2ClientDemo {

	

	public static void main(string[] args)
			throws InterruptedException, ExecutionException, UnsupportedEncodingException {
		final Http2Configuration http2Configuration = new Http2Configuration();
		http2Configuration.setSecureConnectionEnabled(true);
		http2Configuration.setFlowControlStrategy("simple");
		http2Configuration.getTcpConfiguration().setTimeout(60 * 1000);
		Http2Client client = new Http2Client(http2Configuration);

		FuturePromise<HttpClientConnection> promise = new FuturePromise<>();
		client.connect("127.0.0.1", 6677, promise, new ClientHttp2SessionListener() {

			override
			public Map<Integer, Integer> onPreface(Session session) {
				info("client preface: {}", session);
				Map<Integer, Integer> settings = new HashMap<>();
				settings.put(SettingsFrame.HEADER_TABLE_SIZE, http2Configuration.getMaxDynamicTableSize());
				settings.put(SettingsFrame.INITIAL_WINDOW_SIZE, http2Configuration.getInitialStreamSendWindow());
				return settings;
			}

			override
			public hunt.http.codec.http.stream.Stream.Listener onNewStream(Stream stream, HeadersFrame frame) {
				return null;
			}

			override
			public void onSettings(Session session, SettingsFrame frame) {
				info("client received settings frame: {}", frame);
			}

			override
			public void onPing(Session session, PingFrame frame) {
			}

			override
			public void onReset(Session session, ResetFrame frame) {
				info("client resets {}", frame);
			}

			override
			public void onClose(Session session, GoAwayFrame frame) {
				info("client is closed {}", frame);
			}

			override
			public void onFailure(Session session, Throwable failure) {
				errorf("client failure, {}", failure, session);
			}

			override
			public bool onIdleTimeout(Session session) {
				return false;
			}
		});

		HttpConnection connection = promise.get();
		HttpFields fields = new HttpFields();
		fields.put(HttpHeader.ACCEPT, "text/html");
		fields.put(HttpHeader.USER_AGENT, "Hunt Client 1.0");
		fields.put(HttpHeader.CONTENT_LENGTH, "28");
		MetaData.Request metaData = new MetaData.Request("POST", HttpScheme.HTTP,
				new HostPortHttpField("127.0.0.1:6677"), "/data", HttpVersion.HTTP_2, fields);

		Http2ClientConnection clientConnection = (Http2ClientConnection) connection;

		FuturePromise<Stream> streamPromise = new FuturePromise<>();
		clientConnection.getHttp2Session().newStream(new HeadersFrame(metaData, null, false), streamPromise,
				new Stream.Listener() {

					override
					public void onHeaders(Stream stream, HeadersFrame frame) {
						info("client received headers: {}", frame);
					}

					override
					public hunt.http.codec.http.stream.Stream.Listener onPush(Stream stream,
							PushPromiseFrame frame) {
						return null;
					}

					override
					public void onData(Stream stream, DataFrame frame, Callback callback) {
						info("client received data: {}, {}", BufferUtils.toUTF8String(frame.getData()), frame);
						callback.succeeded();
					}

					override
					public void onReset(Stream stream, ResetFrame frame) {
						info("client reset: {}, {}", stream, frame);
					}

					override
					public bool onIdleTimeout(Stream stream, Throwable x) {
						errorf("the client stream {} is timeout", x, stream);
						return true;
					}

					
				});

		final Stream clientStream = streamPromise.get();
		info("client stream id is ", clientStream.getId());

		final DataFrame smallDataFrame = new DataFrame(clientStream.getId(),
				ByteBuffer.wrap("hello world!".getBytes("UTF-8")), false);
		final DataFrame bigDataFrame = new DataFrame(clientStream.getId(),
				ByteBuffer.wrap("big hello world!".getBytes("UTF-8")), true);

		clientStream.data(smallDataFrame, new Callback() {

			override
			public void succeeded() {
				info("client sents small data success");
				clientStream.data(bigDataFrame, new Callback() {

					override
					public void succeeded() {
						info("client sents big data success");

					}

					override
					public void failed(Throwable x) {
						info("client sents big data failure");
					}
				});
			}

			override
			public void failed(Throwable x) {
				info("client sents small data failure");
			}
		});

	}
}
