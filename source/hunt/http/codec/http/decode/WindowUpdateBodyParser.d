module hunt.http.codec.http.decode.WindowUpdateBodyParser;

import hunt.container.ByteBuffer;

import hunt.http.codec.http.decode.BodyParser;
import hunt.http.codec.http.decode.HeaderParser;
import hunt.http.codec.http.decode.Parser;

import hunt.http.codec.http.frame.ErrorCode;
import hunt.http.codec.http.frame.WindowUpdateFrame;

import hunt.lang.exception;

/**
*/
class WindowUpdateBodyParser :BodyParser {
	private State state = State.PREPARE;
	private int cursor;
	private int windowDelta;

	this(HeaderParser headerParser, Parser.Listener listener) {
		super(headerParser, listener);
	}

	private void reset() {
		state = State.PREPARE;
		cursor = 0;
		windowDelta = 0;
	}

	override
	bool parse(ByteBuffer buffer) {
		while (buffer.hasRemaining()) {
			switch (state) {
			case State.PREPARE: {
				int length = getBodyLength();
				if (length != 4)
					return connectionFailure(buffer, cast(int)ErrorCode.FRAME_SIZE_ERROR, "invalid_window_update_frame");
				state = State.WINDOW_DELTA;
				break;
			}
			case State.WINDOW_DELTA: {
				if (buffer.remaining() >= 4) {
					windowDelta = buffer.get!int() & 0x7F_FF_FF_FF;
					return onWindowUpdate(windowDelta);
				} else {
					state = State.WINDOW_DELTA_BYTES;
					cursor = 4;
				}
				break;
			}
			case State.WINDOW_DELTA_BYTES: {
				byte currByte = buffer.get();
				--cursor;
				windowDelta += (currByte & 0xFF) << 8 * cursor;
				if (cursor == 0) {
					windowDelta &= 0x7F_FF_FF_FF;
					return onWindowUpdate(windowDelta);
				}
				break;
			}
			default: {
				throw new IllegalStateException("");
			}
			}
		}
		return false;
	}

	private bool onWindowUpdate(int windowDelta) {
		WindowUpdateFrame frame = new WindowUpdateFrame(getStreamId(), windowDelta);
		reset();
		notifyWindowUpdate(frame);
		return true;
	}

	private enum State {
		PREPARE, WINDOW_DELTA, WINDOW_DELTA_BYTES
	}
}
