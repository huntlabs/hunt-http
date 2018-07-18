module hunt.http.codec.http.frame.WindowUpdateFrame;

import hunt.http.codec.http.frame.Frame;
import hunt.http.codec.http.frame.FrameType;

import std.format;

class WindowUpdateFrame :Frame {
	private int streamId;
	private int windowDelta;

	this(int streamId, int windowDelta) {
		super(FrameType.WINDOW_UPDATE);
		this.streamId = streamId;
		this.windowDelta = windowDelta;
	}

	int getStreamId() {
		return streamId;
	}

	int getWindowDelta() {
		return windowDelta;
	}

	override
	string toString() {
		return format("%s#%d,delta=%d", super.toString(), streamId, windowDelta);
	}
}
