module hunt.http.codec.http.frame.PingFrame;

import hunt.http.codec.http.frame.Frame;
import hunt.http.codec.http.frame.FrameType;

import hunt.lang.exception;

class PingFrame :Frame {
	static int PING_LENGTH = 8;
	private static byte[] EMPTY_PAYLOAD = new byte[8];

	private byte[] payload;
	private bool reply;

	/**
	 * Creates a PING frame with an empty payload.
	 *
	 * @param reply
	 *            whether this PING frame is a reply
	 */
	this(bool reply) {
		this(EMPTY_PAYLOAD, reply);
	}

	/**
	 * Creates a PING frame with the given {@code long} {@code value} as
	 * payload.
	 *
	 * @param value
	 *            the value to use as a payload for this PING frame
	 * @param reply
	 *            whether this PING frame is a reply
	 */
	this(long value, bool reply) {
		this(toBytes(value), reply);
	}

	/**
	 * Creates a PING frame with the given {@code payload}.
	 *
	 * @param payload
	 *            the payload for this PING frame
	 * @param reply
	 *            whether this PING frame is a reply
	 */
	this(byte[] payload, bool reply) {
		assert(payload !is null);
		super(FrameType.PING);
		this.payload = payload;
		if (payload.length != PING_LENGTH)
			throw new IllegalArgumentException("PING payload must be 8 bytes");
		this.reply = reply;
	}

	byte[] getPayload() {
		return payload;
	}

	long getPayloadAsLong() {
		return toLong(payload);
	}

	bool isReply() {
		return reply;
	}

	private static byte[] toBytes(long value) {
		byte[] result = new byte[8];
		for (size_t i = result.length - 1; i >= 0; --i) {
			result[i] = cast(byte) (value & 0xFF);
			value >>= 8;
		}
		return result;
	}

	private static long toLong(byte[] payload) {
		long result = 0;
		for (size_t i = 0; i < 8; ++i) {
			result <<= 8;
			result |= (payload[i] & 0xFF);
		}
		return result;
	}
}
