module hunt.http.codec.http.encode.DataGenerator;

import hunt.http.codec.http.encode.HeaderGenerator;

import hunt.http.codec.http.frame.DataFrame;
import hunt.http.codec.http.frame.Flags;
import hunt.http.codec.http.frame.Frame;
import hunt.http.codec.http.frame.FrameType;

import hunt.container;
import hunt.util.exception;

import std.algorithm;
import std.conv;
import std.typecons;


/**
*/
class DataGenerator {
	private HeaderGenerator headerGenerator;

	this(HeaderGenerator headerGenerator) {
		this.headerGenerator = headerGenerator;
	}

	Tuple!(int, List!(ByteBuffer))   generate(DataFrame frame, int maxLength) {
		return generateData(frame.getStreamId(), frame.getData(), frame.isEndStream(), maxLength);
	}

	Tuple!(int, List!(ByteBuffer)) generateData(int streamId, ByteBuffer data, bool last, int maxLength) {
		if (streamId < 0)
			throw new IllegalArgumentException("Invalid stream id: " ~ streamId.to!string);

		List!ByteBuffer list = new LinkedList!(ByteBuffer)();

		int dataLength = data.remaining();
		int maxFrameSize = headerGenerator.getMaxFrameSize();
		int length = std.algorithm.min(dataLength, std.algorithm.min(maxFrameSize, maxLength));
		if (length == dataLength) {
			generateFrame(streamId, data, last, list);
		} else {
			int limit = data.limit();
			int newLimit = data.position() + length;
			data.limit(newLimit);
			ByteBuffer slice = data.slice();
			data.position(newLimit);
			data.limit(limit);
			generateFrame(streamId, slice, false, list);
		}
		return tuple(length + Frame.HEADER_LENGTH, list);
	}

	private void generateFrame(int streamId, ByteBuffer data, bool last, List!ByteBuffer list) {
		int length = data.remaining();

		int flags = Flags.NONE;
		if (last)
			flags |= Flags.END_STREAM;

		ByteBuffer header = headerGenerator.generate(FrameType.DATA, Frame.HEADER_LENGTH + length, length, flags,
				streamId);

		BufferUtils.flipToFlush(header, 0);
		list.add(header);

		if (data.remaining() > 0)
			list.add(data);
	}

}
