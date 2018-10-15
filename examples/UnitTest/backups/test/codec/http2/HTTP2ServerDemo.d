module test.codec.http2;

import hunt.http.codec.http.frame;
import hunt.http.codec.http.stream.Http2Configuration;
import hunt.http.codec.http.stream.Session;
import hunt.http.codec.http.stream.Stream;
import hunt.http.codec.http.stream.Stream.Listener;
import hunt.http.server.HttpServer;
import hunt.http.server.ServerHttpHandler;
import hunt.http.server.ServerSessionListener;
import hunt.http.server.WebSocketHandler;
import hunt.lang.common;
import hunt.container.BufferUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.HashMap;
import java.util.Map;

public class Http2ServerDemo {

	

	public static void main(string[] args) {
		final Http2Configuration http2Configuration = new Http2Configuration();
		http2Configuration.setSecureConnectionEnabled(true);
		http2Configuration.setFlowControlStrategy("simple");
		http2Configuration.getTcpConfiguration().setTimeout(60 * 1000);

		final Map<Integer, Integer> settings = new HashMap<>();
		settings.put(SettingsFrame.HEADER_TABLE_SIZE, http2Configuration.getMaxDynamicTableSize());
		settings.put(SettingsFrame.INITIAL_WINDOW_SIZE, http2Configuration.getInitialStreamSendWindow());

		HttpServer server = new HttpServer("127.0.0.1", 6677, http2Configuration, new ServerSessionListener() {

			override
			public Map<Integer, Integer> onPreface(Session session) {
				info("server received preface: {}", session);
				return settings;
			}

			override
			public Listener onNewStream(Stream stream, HeadersFrame frame) {
				info("server created new stream: {}", stream.getId());
				info("server created new stream headers: {}", frame.getMetaData().toString());

				return new Listener() {

					override
					public void onHeaders(Stream stream, HeadersFrame frame) {
						info("server received headers: {}", frame.getMetaData());
					}

					override
					public Listener onPush(Stream stream, PushPromiseFrame frame) {
						return null;
					}

					override
					public void onData(Stream stream, DataFrame frame, Callback callback) {
						info("server received data {}, {}", BufferUtils.toUTF8String(frame.getData()), frame);
						callback.succeeded();
					}

					override
					public void onReset(Stream stream, ResetFrame frame) {
						info("server reseted: {} | {}", stream, frame);
					}

					override
					public bool onIdleTimeout(Stream stream, Throwable x) {
						info("idle timeout", x);
						return true;
					}


				};
			}

			override
			public void onSettings(Session session, SettingsFrame frame) {
				info("server received settings: {}", frame);
			}

			override
			public void onPing(Session session, PingFrame frame) {
			}

			override
			public void onReset(Session session, ResetFrame frame) {
				info("server reset " ~ frame);
			}

			override
			public void onClose(Session session, GoAwayFrame frame) {
				info("server closed " ~ frame);
			}

			override
			public void onFailure(Session session, Throwable failure) {
				errorf("server failure, {}", failure, session);
			}

			override
			public void onAccept(Session session) {
			}

			override
			public bool onIdleTimeout(Session session) {
				return false;
			}
		}, new ServerHttpHandlerAdapter(), new WebSocketHandler() {});

		server.start();
	}
}
