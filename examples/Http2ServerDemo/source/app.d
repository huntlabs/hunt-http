import std.stdio;


import hunt.http.codec.http.frame;
import hunt.http.codec.http.model.HttpVersion;
import hunt.http.codec.http.stream;

import hunt.http.server.http.HTTP2Server;
import hunt.http.server.http.ServerHTTPHandler;
import hunt.http.server.http.ServerSessionListener;
// import hunt.http.server.http2.WebSocketHandler;

import hunt.util.functional;
import hunt.container;

import kiss.logger;


void main(string[] args)
{
	HTTP2Configuration http2Configuration = new HTTP2Configuration();
	http2Configuration.setSecureConnectionEnabled(true);
	http2Configuration.setFlowControlStrategy("simple");
	http2Configuration.getTcpConfiguration().setTimeout(60 * 1000);
	http2Configuration.setProtocol(HttpVersion.HTTP_1_1.asString());

	Map!(int, int) settings = new HashMap!(int, int)();
	settings.put(SettingsFrame.HEADER_TABLE_SIZE, http2Configuration.getMaxDynamicTableSize());
	settings.put(SettingsFrame.INITIAL_WINDOW_SIZE, http2Configuration.getInitialStreamSendWindow());

	HTTP2Server server = new HTTP2Server("0.0.0.0", 6677, http2Configuration, new class ServerSessionListener {

		override
		Map!(int, int) onPreface(Session session) {
			infof("server received preface: %s", session);
			return settings;
		}

		override
		StreamListener onNewStream(Stream stream, HeadersFrame frame) {
			infof("server created new stream: %s", stream.getId());
			infof("server created new stream headers: %s", frame.getMetaData().toString());

			return new class StreamListener {

				override
				void onHeaders(Stream stream, HeadersFrame frame) {
					infof("server received headers: %s", frame.getMetaData());
				}

				override
				StreamListener onPush(Stream stream, PushPromiseFrame frame) {
					return null;
				}

				override
				void onData(Stream stream, DataFrame frame, Callback callback) {
					infof("server received data %s, %s", BufferUtils.toString(frame.getData()), frame);
					callback.succeeded();
				}

				void onReset(Stream stream, ResetFrame frame, Callback callback) {
					try {
						onReset(stream, frame);
						callback.succeeded();
					} catch (Exception x) {
						callback.failed(x);
					}
				}

				override
				void onReset(Stream stream, ResetFrame frame) {
					infof("server reseted: %s | %s", stream, frame);
				}

				override
				bool onIdleTimeout(Stream stream, Exception x) {
					infof("idle timeout", x);
					return true;
				}

				override string toString() {
					return super.toString();
				}

			};
		}

		override
		void onSettings(Session session, SettingsFrame frame) {
			infof("server received settings: %s", frame);
		}

		override
		void onPing(Session session, PingFrame frame) {
		}

		override
		void onReset(Session session, ResetFrame frame) {
			infof("server reset " ~ frame.toString());
		}

		override
		void onClose(Session session, GoAwayFrame frame) {
			infof("server closed " ~ frame.toString());
		}

		override
		void onFailure(Session session, Exception failure) {
			errorf("server failure, %s", failure, session);
		}

		void onClose(Session session, GoAwayFrame frame, Callback callback)
		{
			try
			{
				onClose(session, frame);
				callback.succeeded();
			}
			catch (Exception x)
			{
				callback.failed(x);
			}
		}

		void onFailure(Session session, Exception failure, Callback callback)
		{
			try
			{
				onFailure(session, failure);
				callback.succeeded();
			}
			catch (Exception x)
			{
				callback.failed(x);
			}
		}

		override
		void onAccept(Session session) {
		}

		override
		bool onIdleTimeout(Session session) {
			return false;
		}
	}, new ServerHTTPHandlerAdapter(), null);

	server.start();
}
