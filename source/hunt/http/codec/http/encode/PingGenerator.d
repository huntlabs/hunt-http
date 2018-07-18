module hunt.http.codec.http.encode.PingGenerator;

import hunt.container;

import hunt.http.codec.http.frame.Flags;
import hunt.http.codec.http.frame.Frame;
import hunt.http.codec.http.frame.FrameType;
import hunt.http.codec.http.frame.PingFrame;

import hunt.http.codec.http.encode.FrameGenerator;
import hunt.http.codec.http.encode.HeaderGenerator;

import hunt.util.exception;
import std.conv;

/**
*/
class PingGenerator :FrameGenerator {
	this(HeaderGenerator headerGenerator) {
		super(headerGenerator);
	}

	override
	List!(ByteBuffer) generate(Frame frame) {
		PingFrame pingFrame = cast(PingFrame) frame;
		return Collections.singletonList(generatePing(pingFrame.getPayload(), pingFrame.isReply()));
	}

	ByteBuffer generatePing(byte[] payload, bool reply) {
		if (payload.length != PingFrame.PING_LENGTH)
			throw new IllegalArgumentException("Invalid payload length: " ~ payload.length.to!string());

		ByteBuffer header = generateHeader(FrameType.PING, PingFrame.PING_LENGTH, reply ? Flags.ACK : Flags.NONE, 0);

		header.put(payload);

		BufferUtils.flipToFlush(header, 0);
		return header;
	}
}
