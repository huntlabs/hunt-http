module hunt.http.codec.http.decode.ContinuationBodyParser;

import hunt.container.ByteBuffer;

import hunt.http.codec.http.decode.BodyParser;
import hunt.http.codec.http.decode.HeaderBlockParser;
import hunt.http.codec.http.decode.HeaderBlockFragments;
import hunt.http.codec.http.decode.HeaderParser;
import hunt.http.codec.http.decode.Parser;

import hunt.http.codec.http.frame.ErrorCode;
import hunt.http.codec.http.frame.Flags;
import hunt.http.codec.http.frame.HeadersFrame;

import hunt.http.codec.http.model.MetaData;

import hunt.util.exception;

/**
*/
class ContinuationBodyParser :BodyParser {
	private HeaderBlockParser headerBlockParser;
	private HeaderBlockFragments headerBlockFragments;
	private State state = State.PREPARE;
	private int length;

	this(HeaderParser headerParser, Parser.Listener listener,
			HeaderBlockParser headerBlockParser, HeaderBlockFragments headerBlockFragments) {
		super(headerParser, listener);
		this.headerBlockParser = headerBlockParser;
		this.headerBlockFragments = headerBlockFragments;
	}

	override
	protected void emptyBody(ByteBuffer buffer) {
		if (hasFlag(Flags.END_HEADERS))
			onHeaders();
	}

	override
	bool parse(ByteBuffer buffer) {
		while (buffer.hasRemaining()) {
			switch (state) {
			case State.PREPARE: {
				// SPEC: wrong streamId is treated as connection error.
				if (getStreamId() == 0)
					return connectionFailure(buffer, cast(int)ErrorCode.PROTOCOL_ERROR, "invalid_continuation_frame");

				if (getStreamId() != headerBlockFragments.getStreamId())
					return connectionFailure(buffer, cast(int)ErrorCode.PROTOCOL_ERROR, "invalid_continuation_stream");

				length = getBodyLength();
				state = State.FRAGMENT;
				break;
			}
			case State.FRAGMENT: {
				int remaining = buffer.remaining();
				if (remaining < length) {
					headerBlockFragments.storeFragment(buffer, remaining, false);
					length -= remaining;
					break;
				} else {
					bool last = hasFlag(Flags.END_HEADERS);
					headerBlockFragments.storeFragment(buffer, length, last);
					reset();
					if (last)
						onHeaders();
					return true;
				}
			}
			default: {
				throw new IllegalStateException("");
			}
			}
		}
		return false;
	}

	private void onHeaders() {
		ByteBuffer headerBlock = headerBlockFragments.complete();
		MetaData metaData = headerBlockParser.parse(headerBlock, headerBlock.remaining());
		HeadersFrame frame = new HeadersFrame(getStreamId(), metaData, headerBlockFragments.getPriorityFrame(),
				headerBlockFragments.isEndStream());
		notifyHeaders(frame);
	}

	private void reset() {
		state = State.PREPARE;
		length = 0;
	}

	private enum State {
		PREPARE, FRAGMENT
	}
}
