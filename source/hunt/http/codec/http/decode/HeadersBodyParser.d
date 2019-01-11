module hunt.http.codec.http.decode.HeadersBodyParser;

import hunt.http.codec.http.decode.BodyParser;
import hunt.http.codec.http.decode.HeaderParser;
import hunt.http.codec.http.decode.HeaderBlockFragments;
import hunt.http.codec.http.decode.HeaderBlockParser;
import hunt.http.codec.http.decode.Parser;

import hunt.http.codec.http.frame.ErrorCode;
import hunt.http.codec.http.frame.Flags;
import hunt.http.codec.http.frame.HeadersFrame;
import hunt.http.codec.http.frame.PriorityFrame;
import hunt.http.codec.http.model.MetaData;

import hunt.collection.BufferUtils;
import hunt.collection.ByteBuffer;

import hunt.Exceptions;

import std.algorithm;

/**
*/
class HeadersBodyParser :BodyParser {
	private HeaderBlockParser headerBlockParser;
	private HeaderBlockFragments headerBlockFragments;
	private State state = State.PREPARE;
	private int cursor;
	private int length;
	private int paddingLength;
	private bool exclusive;
	private int parentStreamId;
	private int weight;

	this(HeaderParser headerParser, Parser.Listener listener, HeaderBlockParser headerBlockParser,
			HeaderBlockFragments headerBlockFragments) {
		super(headerParser, listener);
		this.headerBlockParser = headerBlockParser;
		this.headerBlockFragments = headerBlockFragments;
	}

	private void reset() {
		state = State.PREPARE;
		cursor = 0;
		length = 0;
		paddingLength = 0;
		exclusive = false;
		parentStreamId = 0;
		weight = 0;
	}

	override
	protected void emptyBody(ByteBuffer buffer) {
		if (hasFlag(Flags.END_HEADERS)) {
			MetaData metaData = headerBlockParser.parse(BufferUtils.EMPTY_BUFFER, 0);
			onHeaders(0, 0, false, metaData);
		} else {
			headerBlockFragments.setStreamId(getStreamId());
			headerBlockFragments.setEndStream(isEndStream());
			if (hasFlag(Flags.PRIORITY))
				connectionFailure(buffer, cast(int)ErrorCode.PROTOCOL_ERROR, "invalid_headers_priority_frame");
		}
	}

	override
	bool parse(ByteBuffer buffer) {
		bool loop = false;
		while (buffer.hasRemaining() || loop) {
			switch (state) {
			case State.PREPARE: {
				// SPEC: wrong streamId is treated as connection error.
				if (getStreamId() == 0)
					return connectionFailure(buffer, cast(int)ErrorCode.PROTOCOL_ERROR, "invalid_headers_frame");

				length = getBodyLength();

				if (isPadding()) {
					state = State.PADDING_LENGTH;
				} else if (hasFlag(Flags.PRIORITY)) {
					state = State.EXCLUSIVE;
				} else {
					state = State.HEADERS;
				}
				break;
			}
			case State.PADDING_LENGTH: {
				paddingLength = buffer.get() & 0xFF;
				--length;
				length -= paddingLength;
				state = hasFlag(Flags.PRIORITY) ? State.EXCLUSIVE : State.HEADERS;
				loop = length == 0;
				if (length < 0)
					return connectionFailure(buffer, cast(int)ErrorCode.FRAME_SIZE_ERROR, "invalid_headers_frame_padding");
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
					length -= 4;
					state = State.WEIGHT;
					if (length < 1)
						return connectionFailure(buffer, cast(int)ErrorCode.FRAME_SIZE_ERROR, "invalid_headers_frame");
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
				--length;
				if (cursor > 0 && length <= 0)
					return connectionFailure(buffer, cast(int)ErrorCode.FRAME_SIZE_ERROR, "invalid_headers_frame");
				if (cursor == 0) {
					parentStreamId &= 0x7F_FF_FF_FF;
					state = State.WEIGHT;
					if (length < 1)
						return connectionFailure(buffer, cast(int)ErrorCode.FRAME_SIZE_ERROR, "invalid_headers_frame");
				}
				break;
			}
			case State.WEIGHT: {
				weight = (buffer.get() & 0xFF) + 1;
				--length;
				state = State.HEADERS;
				loop = length == 0;
				break;
			}
			case State.HEADERS: {
				if (hasFlag(Flags.END_HEADERS)) {
					MetaData metaData = headerBlockParser.parse(buffer, length);
					if (metaData !is null) {
						state = State.PADDING;
						loop = paddingLength == 0;
						onHeaders(parentStreamId, weight, exclusive, metaData);
					}
				} else {
					int remaining = buffer.remaining();
					if (remaining < length) {
						headerBlockFragments.storeFragment(buffer, remaining, false);
						length -= remaining;
					} else {
						headerBlockFragments.setStreamId(getStreamId());
						headerBlockFragments.setEndStream(isEndStream());
						if (hasFlag(Flags.PRIORITY))
							headerBlockFragments.setPriorityFrame(
									new PriorityFrame(getStreamId(), parentStreamId, weight, exclusive));
						headerBlockFragments.storeFragment(buffer, length, false);
						state = State.PADDING;
						loop = paddingLength == 0;
					}
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

	private void onHeaders(int parentStreamId, int weight, bool exclusive, MetaData metaData) {
		PriorityFrame priorityFrame = null;
		if (hasFlag(Flags.PRIORITY))
			priorityFrame = new PriorityFrame(getStreamId(), parentStreamId, weight, exclusive);
		HeadersFrame frame = new HeadersFrame(getStreamId(), metaData, priorityFrame, isEndStream());
		notifyHeaders(frame);
	}

	private enum State {
		PREPARE, PADDING_LENGTH, EXCLUSIVE, PARENT_STREAM_ID, PARENT_STREAM_ID_BYTES, WEIGHT, HEADERS, PADDING
	}
}
