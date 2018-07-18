module hunt.http.codec.http.decode.PingBodyParser;

import hunt.container.ByteBuffer;

import hunt.http.codec.http.decode.BodyParser;
import hunt.http.codec.http.decode.HeaderParser;
import hunt.http.codec.http.decode.Parser;

import hunt.http.codec.http.frame.ErrorCode;
import hunt.http.codec.http.frame.Flags;
import hunt.http.codec.http.frame.PingFrame;

import hunt.util.exception;

/**
*/
class PingBodyParser :BodyParser {
	private State state = State.PREPARE;
	private int cursor;
	private byte[] payload;

	this(HeaderParser headerParser, Parser.Listener listener) {
		super(headerParser, listener);
	}

	private void reset() {
		state = State.PREPARE;
		cursor = 0;
		payload = null;
	}

	override
	bool parse(ByteBuffer buffer) {
		while (buffer.hasRemaining()) {
			switch (state) {
			case State.PREPARE: {
				// SPEC: wrong streamId is treated as connection error.
				if (getStreamId() != 0)
					return connectionFailure(buffer, cast(int)ErrorCode.PROTOCOL_ERROR, "invalid_ping_frame");
				// SPEC: wrong body length is treated as connection error.
				if (getBodyLength() != 8)
					return connectionFailure(buffer, cast(int)ErrorCode.FRAME_SIZE_ERROR, "invalid_ping_frame");
				state = State.PAYLOAD;
				break;
			}
			case State.PAYLOAD: {
				payload = new byte[8];
				if (buffer.remaining() >= 8) {
					buffer.get(payload);
					return onPing(payload);
				} else {
					state = State.PAYLOAD_BYTES;
					cursor = 8;
				}
				break;
			}
			case State.PAYLOAD_BYTES: {
				payload[8 - cursor] = buffer.get();
				--cursor;
				if (cursor == 0)
					return onPing(payload);
				break;
			}
			default: {
				throw new IllegalStateException("");
			}
			}
		}
		return false;
	}

	private bool onPing(byte[] payload) {
		PingFrame frame = new PingFrame(payload, hasFlag(Flags.ACK));
		reset();
		notifyPing(frame);
		return true;
	}

	private enum State {
		PREPARE, PAYLOAD, PAYLOAD_BYTES
	}
}
