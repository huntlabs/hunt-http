module hunt.http.codec.http.decode.ServerParser;


import hunt.http.codec.http.decode.PrefaceParser;
import hunt.http.codec.http.decode.Parser;
import hunt.http.codec.http.frame.ErrorCode;
import hunt.http.codec.http.frame.Flags;
import hunt.http.codec.http.frame.FrameType;

import hunt.container.ByteBuffer;
import hunt.container.BufferUtils;

import kiss.logger;
import hunt.util.exception;


/**
*/
class ServerParser :Parser {

	private Listener listener;
	private PrefaceParser prefaceParser;
	private State state = State.PREFACE;
	private bool _notifyPreface = true;

	this(Listener listener, int maxDynamicTableSize, int maxHeaderSize) {
		super(listener, maxDynamicTableSize, maxHeaderSize);
		this.listener = listener;
		this.prefaceParser = new PrefaceParser(listener);
	}

	/**
	 * <p>
	 * A direct upgrade is an unofficial upgrade from HTTP/1.1 to HTTP/2.0.
	 * </p>
	 * <p>
	 * A direct upgrade is initiated when
	 * HTTP connection sees a request with these
	 * bytes:
	 * </p>
	 * 
	 * <pre>
	 * PRI * HTTP/2.0\r\n
	 * \r\n
	 * </pre>
	 * <p>
	 * This request is part of the HTTP/2.0 preface, indicating that a HTTP/2.0
	 * client is attempting a h2c direct connection.
	 * </p>
	 * <p>
	 * This is not a standard HTTP/1.1 Upgrade path.
	 * </p>
	 */
	void directUpgrade() {
		if (state != State.PREFACE)
			throw new IllegalStateException("");
		prefaceParser.directUpgrade();
	}

	/**
	 * <p>
	 * The standard HTTP/1.1 upgrade path.
	 * </p>
	 */
	void standardUpgrade() {
		if (state != State.PREFACE)
			throw new IllegalStateException("");
		_notifyPreface = false;
	}

	override
	void parse(ByteBuffer buffer) {
		try {
			while (true) {
				switch (state) {
				case State.PREFACE: {
					if (prefaceParser.parse(buffer)) {
						if (_notifyPreface) {
							onPreface();
						}
						state = State.SETTINGS;
						break;
					} else {
						return;
					}
				}
				case State.SETTINGS: {
					if (parseHeader(buffer)) {
						if (getFrameType() != FrameType.SETTINGS || hasFlag(Flags.ACK)) {
							buffer.clear();
							notifyConnectionFailure(cast(int)ErrorCode.PROTOCOL_ERROR, "invalid_preface");
							return;
						}
						if (parseBody(buffer)) {
							state = State.FRAMES;
							break;
						} else {
							return;
						}
					} else {
						return;
					}
				}
				case State.FRAMES: {
					// Stay forever in the FRAMES state.
					super.parse(buffer);
					return;
				}
				default: {
					throw new IllegalStateException("");
				}
				}
			}
		} catch (Exception x) {
			errorf("server parser error", x);
			BufferUtils.clear(buffer);
			notifyConnectionFailure(cast(int)ErrorCode.PROTOCOL_ERROR, "parser_error");
		}
	}

	protected void onPreface() {
		notifyPreface();
	}

	private void notifyPreface() {
		try {
			listener.onPreface();
		} catch (Exception x) {
			errorf("Failure while notifying listener %s", x.message);
		}
	}

	interface Listener : Parser.Listener {
		void onPreface();

		class Adapter : Parser.Listener.Adapter, Listener {
			override
			void onPreface() {
			}
		}
	}

	private enum State {
		PREFACE, SETTINGS, FRAMES
	}
}
