module hunt.http.codec.http.decode.ResetBodyParser;

import hunt.collection.ByteBuffer;

import hunt.http.codec.http.decode.BodyParser;
import hunt.http.codec.http.decode.HeaderParser;
import hunt.http.codec.http.decode.Parser;

import hunt.http.codec.http.frame.ErrorCode;
import hunt.http.codec.http.frame.ResetFrame;

import hunt.Exceptions;

/**
*/
class ResetBodyParser :BodyParser {
	private State state = State.PREPARE;
	private int cursor;
	private int error;

	this(HeaderParser headerParser, Parser.Listener listener) {
		super(headerParser, listener);
	}

	private void reset() {
		state = State.PREPARE;
		cursor = 0;
		error = 0;
	}

	override
	bool parse(ByteBuffer buffer) {
		while (buffer.hasRemaining()) {
			switch (state) {
			case State.PREPARE: {
				// SPEC: wrong streamId is treated as connection error.
				if (getStreamId() == 0)
					return connectionFailure(buffer, cast(int)ErrorCode.PROTOCOL_ERROR, "invalid_rst_stream_frame");
				int length = getBodyLength();
				if (length != 4)
					return connectionFailure(buffer, cast(int)ErrorCode.FRAME_SIZE_ERROR, "invalid_rst_stream_frame");
				state = State.ERROR;
				break;
			}
			case State.ERROR: {
				if (buffer.remaining() >= 4) {
					return onReset(buffer.get!int());
				} else {
					state = State.ERROR_BYTES;
					cursor = 4;
				}
				break;
			}
			case State.ERROR_BYTES: {
				int currByte = buffer.get() & 0xFF;
				--cursor;
				error += currByte << (8 * cursor);
				if (cursor == 0)
					return onReset(error);
				break;
			}
			default: {
				throw new IllegalStateException("");
			}
			}
		}
		return false;
	}

	private bool onReset(int error) {
		ResetFrame frame = new ResetFrame(getStreamId(), error);
		reset();
		notifyReset(frame);
		return true;
	}

	private enum State {
		PREPARE, ERROR, ERROR_BYTES
	}
}
