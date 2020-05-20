module hunt.http.codec.http.frame.DataFrame;

import hunt.io.ByteBuffer;

import hunt.http.codec.http.frame.Frame;
import hunt.http.codec.http.frame.FrameType;

import std.format;

class DataFrame :Frame {
	private int streamId;
	private ByteBuffer data;
	private bool endStream;
	private int _padding;

	this(int streamId, ByteBuffer data, bool endStream) {
		this(streamId, data, endStream, 0);
	}

	this(int streamId, ByteBuffer data, bool endStream, int padding) {
		super(FrameType.DATA);
		this.streamId = streamId;
		this.data = data;
		this.endStream = endStream;
		this._padding = padding;
	}

	int getStreamId() {
		return streamId;
	}

	ByteBuffer getData() {
		return data;
	}

	bool isEndStream() {
		return endStream;
	}

	/**
	 * @return the number of data bytes remaining.
	 */
	int remaining() {
		return data.remaining();
	}

	/**
	 * @return the number of bytes used for padding that count towards flow
	 *         control.
	 */
	int padding() {
		return _padding;
	}

	override
	string toString() {
		return format("%s#%d{length:%d,end=%b}", super.toString(), streamId, data.remaining(), endStream);
	}
}
