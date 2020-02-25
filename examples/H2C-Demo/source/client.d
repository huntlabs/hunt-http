module client;

import std.stdio;

// import hunt.http.client.ClientHttp2SessionListener;
// import hunt.http.client.HttpClient;
// import hunt.http.client.Http2ClientConnection;
// import hunt.http.client.HttpClientConnection;

import hunt.http.client;
import hunt.http.codec.http.frame;
import hunt.http.codec.http.model;
import hunt.http.codec.http.stream;

import hunt.collection;
import hunt.concurrency.FuturePromise;
import hunt.Exceptions;
import hunt.logging;
import hunt.util.Common;

import core.time;
import std.format;


void main(string[] args) {

	enum host = "127.0.0.1";
	enum port = 8080;

	HttpClientOptions clientOptions = new HttpClientOptions();
	clientOptions.setSecureConnectionEnabled(false);
	clientOptions.setFlowControlStrategy("simple");
	clientOptions.getTcpConfiguration().setIdleTimeout(60.seconds);
	clientOptions.setProtocol(HttpVersion.HTTP_2.toString());

	FuturePromise!(HttpClientConnection) promise = new FuturePromise!(HttpClientConnection)();
	HttpClient client = new HttpClient(clientOptions);

	client.connect(host, port, promise, new class ClientHttp2SessionListener {

		override
		Map!(int, int) onPreface(Session session) {
			infof("client preface: %s", session);
			Map!(int, int) settings = new HashMap!(int, int)();
			settings.put(SettingsFrame.HEADER_TABLE_SIZE, clientOptions.getMaxDynamicTableSize());
			settings.put(SettingsFrame.INITIAL_WINDOW_SIZE, clientOptions.getInitialStreamSendWindow());
			return settings;
		}

		override
		StreamListener onNewStream(Stream stream, HeadersFrame frame) {
			return null;
		}

		override
		void onSettings(Session session, SettingsFrame frame) {
			infof("client received settings frame: %s", frame.toString());
		}

		override
		void onPing(Session session, PingFrame frame) {
		}

		override
		void onReset(Session session, ResetFrame frame) {
			infof("client resets %s", frame.toString());
		}

		override
		void onClose(Session session, GoAwayFrame frame) {
			infof("client is closed %s", frame.toString());
		}

		override
		void onFailure(Session session, Exception failure) {
			errorf("client failure, %s", failure, session);
		}

		override
		bool onIdleTimeout(Session session) {
			return false;
		}
	});


	HttpFields fields = new HttpFields();
	fields.put(HttpHeader.ACCEPT, "text/html");
	fields.put(HttpHeader.USER_AGENT, "Hunt Client 1.0");
	fields.put(HttpHeader.CONTENT_LENGTH, "28");

	HttpRequest metaData = new HttpRequest("POST", HttpScheme.HTTP, host, port,
			"/data", HttpVersion.HTTP_2, fields);

	HttpConnection connection = promise.get();
	Http2ClientConnection clientConnection = cast(Http2ClientConnection) connection;

	FuturePromise!(Stream) streamPromise = new FuturePromise!(Stream)();
	auto http2Session = clientConnection.getHttp2Session();
	http2Session.newStream(new HeadersFrame(metaData, null, false), streamPromise,
		new class StreamListener {

			override
			void onHeaders(Stream stream, HeadersFrame frame) {
				infof("client received headers: %s", frame.toString());
			}

			override
			StreamListener onPush(Stream stream,
					PushPromiseFrame frame) {
				return null;
			}

			override
			void onData(Stream stream, DataFrame frame, hunt.util.Common.Callback callback) {
				infof("client received data: %s, %s", BufferUtils.toString(frame.getData()), frame.toString());
				callback.succeeded();
			}

			void onReset(Stream stream, ResetFrame frame, hunt.util.Common.Callback callback) {
				try {
					onReset(stream, frame);
					callback.succeeded();
				} catch (Exception x) {
					callback.failed(x);
				}
			}

			override
			void onReset(Stream stream, ResetFrame frame) {
				infof("client reset: %s, %s", stream, frame.toString());
			}

			override
			bool onIdleTimeout(Stream stream, Exception x) {
				errorf("the client stream %s is timeout", stream.toString());
				return true;
			}

			override string toString()
			{
				return super.toString();
			}
			
		}
	);

	Stream clientStream = streamPromise.get();
	infof("client stream id is %d", clientStream.getId());

	DataFrame smallDataFrame = new DataFrame(clientStream.getId(),
			BufferUtils.toBuffer(cast(byte[])"hello world!"), false);
			
	DataFrame bigDataFrame = new DataFrame(clientStream.getId(),
			BufferUtils.toBuffer(cast(byte[])"big hello world!"), true);

	clientStream.data(smallDataFrame, new class NoopCallback {

		override
		void succeeded() {
			infof("client sent small data successfully");
			clientStream.data(bigDataFrame, new class NoopCallback {

				override
				void succeeded() {
					infof("client sent big data successfully");
				}

				override
				void failed(Exception x) {
					warning("client failed to send big data ");
				}
			});
		}

		override
		void failed(Exception x) {
			infof("client sends small data failure");
		}
	});

}