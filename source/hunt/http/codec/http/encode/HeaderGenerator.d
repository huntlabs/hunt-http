module hunt.http.codec.http.encode.HeaderGenerator;

import hunt.collection.ByteBuffer;

import hunt.http.codec.http.frame.Frame;
import hunt.http.codec.http.frame.FrameType;

class HeaderGenerator {
	private int maxFrameSize = Frame.DEFAULT_MAX_LENGTH;
	
	ByteBuffer generate(FrameType frameType, int capacity, int length, int flags, int streamId) {
		ByteBuffer header = ByteBuffer.allocate(capacity);
		header.put(cast(byte)((length & 0x00_FF_00_00) >>> 16));
        header.put(cast(byte)((length & 0x00_00_FF_00) >>> 8));
        header.put(cast(byte)((length & 0x00_00_00_FF)));
        header.put(cast(byte)frameType);
        header.put(cast(byte)flags);
        header.put!int(streamId);
        return header;
	}

	int getMaxFrameSize() {
		return maxFrameSize;
	}

	void setMaxFrameSize(int maxFrameSize) {
		this.maxFrameSize = maxFrameSize;
	}
	
}
