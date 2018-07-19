import std.stdio;

import hunt.http.client.http.ClientHTTP2SessionListener;
import hunt.http.client.http.HTTP2Client;
import hunt.http.client.http.HTTP2ClientConnection;
import hunt.http.client.http.HTTPClientConnection;

import hunt.http.codec.http.frame;
import hunt.http.codec.http.model;
import hunt.http.codec.http.stream;

import hunt.util.exception;
import hunt.util.functional;
import hunt.util.concurrent.FuturePromise;

import hunt.container;
import kiss.logger;
import std.format;


void main(string[] args) {

	// enum host = "127.0.0.1";
	enum host = "10.1.222.120";
	enum port = 6677;

	HTTP2Configuration http2Configuration = new HTTP2Configuration();
	http2Configuration.setSecureConnectionEnabled(false);
	http2Configuration.setFlowControlStrategy("simple");
	http2Configuration.getTcpConfiguration().setTimeout(60 * 1000);
	http2Configuration.setProtocol(HttpVersion.HTTP_2.asString());

	FuturePromise!(HTTPClientConnection) promise = new FuturePromise!(HTTPClientConnection)();
	HTTP2Client client = new HTTP2Client(http2Configuration);

	client.connect(host, port, promise, new class ClientHTTP2SessionListener {

		override
		Map!(int, int) onPreface(Session session) {
			infof("client preface: %s", session);
			Map!(int, int) settings = new HashMap!(int, int)();
			settings.put(SettingsFrame.HEADER_TABLE_SIZE, http2Configuration.getMaxDynamicTableSize());
			settings.put(SettingsFrame.INITIAL_WINDOW_SIZE, http2Configuration.getInitialStreamSendWindow());
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
	MetaData.Request metaData = new MetaData.Request("POST", HttpScheme.HTTP,
			new HostPortHttpField(format("%s:%d", host, port)), "/data", HttpVersion.HTTP_2, fields);

	HTTPConnection connection = promise.get();
	HTTP2ClientConnection clientConnection = cast(HTTP2ClientConnection) connection;

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
			void onData(Stream stream, DataFrame frame, Callback callback) {
				infof("client received data: %s, %s", BufferUtils.toString(frame.getData()), frame.toString());
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
			ByteBuffer.wrap(cast(byte[])"hello world!"), false);
	DataFrame bigDataFrame = new DataFrame(clientStream.getId(),
			ByteBuffer.wrap(cast(byte[])"big hello world!"), true);

	clientStream.data(smallDataFrame, new class NoopCallback {

		override
		void succeeded() {
			infof("client sents small data success");
			clientStream.data(bigDataFrame, new class NoopCallback {

				override
				void succeeded() {
					infof("client sents big data success");
				}

				override
				void failed(Exception x) {
					infof("client sents big data failure");
				}
			});
		}

		override
		void failed(Exception x) {
			infof("client sents small data failure");
		}
	});

}