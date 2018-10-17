module hunt.http.codec.http.decode.GoAwayBodyParser;

import hunt.container.ByteBuffer;

import hunt.http.codec.http.decode.BodyParser;
import hunt.http.codec.http.decode.HeaderParser;
import hunt.http.codec.http.decode.Parser;

import hunt.http.codec.http.frame.ErrorCode;
import hunt.http.codec.http.frame.GoAwayFrame;

import hunt.lang.exception;

/**
*/
class GoAwayBodyParser :BodyParser {
	private State state = State.PREPARE;
	private int cursor;
	private int length;
	private int lastStreamId;
	private int error;
	private byte[] payload;

	this(HeaderParser headerParser, Parser.Listener listener) {
		super(headerParser, listener);
	}

	private void reset() {
		state = State.PREPARE;
		cursor = 0;
		length = 0;
		lastStreamId = 0;
		error = 0;
		payload = null;
	}

	override
	bool parse(ByteBuffer buffer) {
		while (buffer.hasRemaining()) {
			switch (state) {
			case State.PREPARE: {
				state = State.LAST_STREAM_ID;
				length = getBodyLength();
				break;
			}
			case State.LAST_STREAM_ID: {
				if (buffer.remaining() >= 4) {
					lastStreamId = buffer.get!int();
					lastStreamId &= 0x7F_FF_FF_FF;
					state = State.ERROR;
					length -= 4;
					if (length <= 0)
						return connectionFailure(buffer, cast(int)ErrorCode.FRAME_SIZE_ERROR, "invalid_go_away_frame");
				} else {
					state = State.LAST_STREAM_ID_BYTES;
					cursor = 4;
				}
				break;
			}
			case State.LAST_STREAM_ID_BYTES: {
				int currByte = buffer.get() & 0xFF;
				--cursor;
				lastStreamId += currByte << (8 * cursor);
				--length;
				if (cursor > 0 && length <= 0)
					return connectionFailure(buffer, cast(int)ErrorCode.FRAME_SIZE_ERROR, "invalid_go_away_frame");
				if (cursor == 0) {
					lastStreamId &= 0x7F_FF_FF_FF;
					state = State.ERROR;
					if (length == 0)
						return connectionFailure(buffer, cast(int)ErrorCode.FRAME_SIZE_ERROR, "invalid_go_away_frame");
				}
				break;
			}
			case State.ERROR: {
				if (buffer.remaining() >= 4) {
					error = buffer.get!int();
					state = State.PAYLOAD;
					length -= 4;
					if (length < 0)
						return connectionFailure(buffer, cast(int)ErrorCode.FRAME_SIZE_ERROR, "invalid_go_away_frame");
					if (length == 0)
						return onGoAway(lastStreamId, error, null);
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
				--length;
				if (cursor > 0 && length <= 0)
					return connectionFailure(buffer, cast(int)ErrorCode.FRAME_SIZE_ERROR, "invalid_go_away_frame");
				if (cursor == 0) {
					state = State.PAYLOAD;
					if (length == 0)
						return onGoAway(lastStreamId, error, null);
				}
				break;
			}
			case State.PAYLOAD: {
				payload = new byte[length];
				if (buffer.remaining() >= length) {
					buffer.get(payload);
					return onGoAway(lastStreamId, error, payload);
				} else {
					state = State.PAYLOAD_BYTES;
					cursor = length;
				}
				break;
			}
			case State.PAYLOAD_BYTES: {
				payload[payload.length - cursor] = buffer.get();
				--cursor;
				if (cursor == 0)
					return onGoAway(lastStreamId, error, payload);
				break;
			}
			default: {
				throw new IllegalStateException("");
			}
			}
		}
		return false;
	}

	private bool onGoAway(int lastStreamId, int error, byte[] payload) {
		GoAwayFrame frame = new GoAwayFrame(lastStreamId, error, payload);
		reset();
		notifyGoAway(frame);
		return true;
	}

	private enum State {
		PREPARE, LAST_STREAM_ID, LAST_STREAM_ID_BYTES, ERROR, ERROR_BYTES, PAYLOAD, PAYLOAD_BYTES
	}
}
