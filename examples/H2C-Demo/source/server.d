module server;

import std.stdio;

import hunt.http.codec.http.frame;
import hunt.http.codec.http.stream;
// import hunt.http.HttpVersion;
import hunt.http.server;

import hunt.util.Common;
import hunt.collection;
import hunt.logging;
import hunt.util.Common;

import core.time;


void main(string[] args)
{
	HttpServerOptions serverOptions = new HttpServerOptions();
	serverOptions.setSecureConnectionEnabled(false);
	serverOptions.setFlowControlStrategy("simple");
	serverOptions.getTcpConfiguration().setIdleTimeout(60.seconds);
	serverOptions.setProtocol(HttpVersion.HTTP_2.toString());
	serverOptions.setHost("0.0.0.0");
	serverOptions.setPort(8080);

	Map!(int, int) settings = new HashMap!(int, int)();
	settings.put(SettingsFrame.HEADER_TABLE_SIZE, serverOptions.getMaxDynamicTableSize());
	settings.put(SettingsFrame.INITIAL_WINDOW_SIZE, serverOptions.getInitialStreamSendWindow());

	HttpServer server = new HttpServer(serverOptions, new class ServerSessionListener {

		override
		Map!(int, int) onPreface(Session session) {
			infof("server received preface: %s", session);
			return settings;
		}

		override
		StreamListener onNewStream(Stream stream, HeadersFrame frame) {
			infof("server created new stream: %d", stream.getId());
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
	}, new ServerHttpHandlerAdapter(serverOptions), null);

	server.start();
}
