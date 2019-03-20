module hunt.http.codec.http.encode.PushPromiseGenerator;

import hunt.collection;

import hunt.http.codec.http.frame.Flags;
import hunt.http.codec.http.frame.Frame;
import hunt.http.codec.http.frame.FrameType;
import hunt.http.codec.http.frame.PushPromiseFrame;
import hunt.http.codec.http.hpack.HpackEncoder;
import hunt.http.codec.http.model.MetaData;

import hunt.http.codec.http.encode.FrameGenerator;
import hunt.http.codec.http.encode.HeaderGenerator;

import hunt.Exceptions;

import std.conv;

/**
*/
class PushPromiseGenerator :FrameGenerator {
	private HpackEncoder encoder;

	this(HeaderGenerator headerGenerator, HpackEncoder encoder) {
		super(headerGenerator);
		this.encoder = encoder;
	}

	override
	List!(ByteBuffer) generate(Frame frame) {
		PushPromiseFrame pushPromiseFrame = cast(PushPromiseFrame) frame;
		return generatePushPromise(pushPromiseFrame.getStreamId(), pushPromiseFrame.getPromisedStreamId(),
				pushPromiseFrame.getMetaData());
	}

	List!(ByteBuffer) generatePushPromise(int streamId, int promisedStreamId, MetaData metaData) {
		if (streamId < 0)
			throw new IllegalArgumentException("Invalid stream id: " ~ streamId.to!string);
		if (promisedStreamId < 0)
			throw new IllegalArgumentException("Invalid promised stream id: " ~ promisedStreamId.to!string);

		List!(ByteBuffer) list = new LinkedList!(ByteBuffer)();
		int maxFrameSize = getMaxFrameSize();
		// The promised streamId space.
		int extraSpace = 4;
		maxFrameSize -= extraSpace;

		ByteBuffer hpacked = BufferUtils.allocate(maxFrameSize);
		BufferUtils.clearToFill(hpacked);
		encoder.encode(hpacked, metaData);
		int hpackedLength = hpacked.position();
		BufferUtils.flipToFlush(hpacked, 0);

		int length = hpackedLength + extraSpace;
		int flags = Flags.END_HEADERS;

		ByteBuffer header = generateHeader(FrameType.PUSH_PROMISE, length, flags, streamId);
		header.put!int(promisedStreamId);
		BufferUtils.flipToFlush(header, 0);

		list.add(header);
		list.add(hpacked);
		return list;
	}
}
