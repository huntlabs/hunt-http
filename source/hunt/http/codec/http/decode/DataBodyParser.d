module hunt.http.codec.http.decode.DataBodyParser;

import hunt.http.codec.http.decode.BodyParser;
import hunt.http.codec.http.decode.HeaderParser;
import hunt.http.codec.http.decode.Parser;

import hunt.http.codec.http.frame.DataFrame;
import hunt.http.codec.http.frame.ErrorCode;

import hunt.collection.BufferUtils;
import hunt.collection.ByteBuffer;

import hunt.Exceptions;
import std.algorithm;
import std.stdio;
/**
*/
class DataBodyParser :BodyParser {
	private State state = State.PREPARE;
	private int padding;
	private int paddingLength;
	private int length;

	this(HeaderParser headerParser, Parser.Listener listener) {
		super(headerParser, listener);
	}

	private void reset() {
		state = State.PREPARE;
		padding = 0;
		paddingLength = 0;
		length = 0;
	}

	override
	protected void emptyBody(ByteBuffer buffer) {
		if (isPadding())
			connectionFailure(buffer, cast(int)ErrorCode.PROTOCOL_ERROR, "invalid_data_frame");
		else
			onData(BufferUtils.EMPTY_BUFFER, false, 0);
	}

	override
	bool parse(ByteBuffer buffer) {
		bool loop = false;
		while (buffer.hasRemaining() || loop) {
			switch (state) {
			case State.PREPARE: {
				// SPEC: wrong streamId is treated as connection error.
				if (getStreamId() == 0)
					return connectionFailure(buffer, cast(int)ErrorCode.PROTOCOL_ERROR, "invalid_data_frame");

				length = getBodyLength();
				state = isPadding() ? State.PADDING_LENGTH : State.DATA;
				break;
			}
			case State.PADDING_LENGTH: {
				padding = 1; // We have seen this byte.
				paddingLength = buffer.get() & 0xFF;
				--length;
				length -= paddingLength;
				state = State.DATA;
				loop = length == 0;
				if (length < 0)
					return connectionFailure(buffer, cast(int)ErrorCode.FRAME_SIZE_ERROR, "invalid_data_frame_padding");
				break;
			}
			case State.DATA: {
				int size = std.algorithm.min(buffer.remaining(), length);
				int position = buffer.position();
				int limit = buffer.limit();
				buffer.limit(position + size);
				ByteBuffer slice = buffer.slice();
				buffer.limit(limit);
				buffer.position(position + size);

				length -= size;
				if (length == 0) {
					state = State.PADDING;
					loop = paddingLength == 0;
					// Padding bytes include the bytes that define the
					// padding length plus the actual padding bytes.
					onData(slice, false, padding + paddingLength);
				} else {
					// We got partial data, simulate a smaller frame, and stay
					// in DATA state.
					// No padding for these synthetic frames (even if we have
					// read
					// the padding length already), it will be accounted at the
					// end.
					onData(slice, true, 0);
				}
				break;
			}
			case State.PADDING: {
				int size = std.algorithm.min(buffer.remaining(), paddingLength);
				buffer.position(buffer.position() + size);
				paddingLength -= size;
				if (paddingLength == 0) {
					reset();
					return true;
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

	private void onData(ByteBuffer buffer, bool fragment, int padding) {
		DataFrame frame = new DataFrame(getStreamId(), buffer, !fragment && isEndStream(), padding);
		notifyData(frame);
	}

	private enum State {
		PREPARE, PADDING_LENGTH, DATA, PADDING
	}
}
