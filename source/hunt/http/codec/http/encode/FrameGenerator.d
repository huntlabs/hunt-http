module hunt.http.codec.http.encode.FrameGenerator;

import hunt.container.ByteBuffer;
import hunt.container.List;

import hunt.http.codec.http.frame.Frame;
import hunt.http.codec.http.frame.FrameType;
import hunt.http.codec.http.encode.HeaderGenerator;


/**
*/
abstract class FrameGenerator {
	private HeaderGenerator headerGenerator;

	this(HeaderGenerator headerGenerator) {
		this.headerGenerator = headerGenerator;
	}

	int getMaxFrameSize() {
		return headerGenerator.getMaxFrameSize();
	}

	protected ByteBuffer generateHeader(FrameType frameType, int length, int flags, int streamId) {
		return headerGenerator.generate(frameType, Frame.HEADER_LENGTH + length, length, flags, streamId);
	}

	abstract List!(ByteBuffer) generate(Frame frame);
}
