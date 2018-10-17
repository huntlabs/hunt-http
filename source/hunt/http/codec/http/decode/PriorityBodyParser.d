module hunt.http.codec.http.decode.PriorityBodyParser;

import hunt.container.ByteBuffer;

import hunt.http.codec.http.decode.BodyParser;
import hunt.http.codec.http.decode.HeaderParser;
import hunt.http.codec.http.decode.Parser;

import hunt.http.codec.http.frame.ErrorCode;
import hunt.http.codec.http.frame.PriorityFrame;

import hunt.lang.exception;

/**
*/
class PriorityBodyParser :BodyParser {
	private State state = State.PREPARE;
	private int cursor;
	private bool exclusive;
	private int parentStreamId;

	this(HeaderParser headerParser, Parser.Listener listener) {
		super(headerParser, listener);
	}

	private void reset() {
		state = State.PREPARE;
		cursor = 0;
		exclusive = false;
		parentStreamId = 0;
	}

	override
	bool parse(ByteBuffer buffer) {
		while (buffer.hasRemaining()) {
			switch (state) {
			case State.PREPARE: {
				// SPEC: wrong streamId is treated as connection error.
				if (getStreamId() == 0)
					return connectionFailure(buffer, cast(int)ErrorCode.PROTOCOL_ERROR, "invalid_priority_frame");
				int length = getBodyLength();
				if (length != 5)
					return connectionFailure(buffer, cast(int)ErrorCode.FRAME_SIZE_ERROR, "invalid_priority_frame");
				state = State.EXCLUSIVE;
				break;
			}
			case State.EXCLUSIVE: {
				// We must only peek the first byte and not advance the buffer
				// because the 31 least significant bits represent the stream
				// id.
				int currByte = buffer.get(buffer.position());
				exclusive = (currByte & 0x80) == 0x80;
				state = State.PARENT_STREAM_ID;
				break;
			}
			case State.PARENT_STREAM_ID: {
				if (buffer.remaining() >= 4) {
					parentStreamId = buffer.get!int();
					parentStreamId &= 0x7F_FF_FF_FF;
					state = State.WEIGHT;
				} else {
					state = State.PARENT_STREAM_ID_BYTES;
					cursor = 4;
				}
				break;
			}
			case State.PARENT_STREAM_ID_BYTES: {
				int currByte = buffer.get() & 0xFF;
				--cursor;
				parentStreamId += currByte << (8 * cursor);
				if (cursor == 0) {
					parentStreamId &= 0x7F_FF_FF_FF;
					state = State.WEIGHT;
				}
				break;
			}
			case State.WEIGHT: {
				// SPEC: stream cannot depend on itself.
				if (getStreamId() == parentStreamId)
					return connectionFailure(buffer, cast(int)ErrorCode.PROTOCOL_ERROR, "invalid_priority_frame");

				int weight = (buffer.get() & 0xFF) + 1;
				return onPriority(parentStreamId, weight, exclusive);
			}
			default: {
				throw new IllegalStateException("");
			}
			}
		}
		return false;
	}

	private bool onPriority(int parentStreamId, int weight, bool exclusive) {
		PriorityFrame frame = new PriorityFrame(getStreamId(), parentStreamId, weight, exclusive);
		reset();
		notifyPriority(frame);
		return true;
	}

	private enum State {
		PREPARE, EXCLUSIVE, PARENT_STREAM_ID, PARENT_STREAM_ID_BYTES, WEIGHT
	}
}
