module hunt.http.codec.http.frame.PushPromiseFrame;

import hunt.http.codec.http.frame.Frame;
import hunt.http.codec.http.frame.FrameType;

import hunt.http.HttpMetaData;

import std.format;

class PushPromiseFrame :Frame {
	private int streamId;
	private int promisedStreamId;
	private HttpMetaData metaData;

	this(int streamId, int promisedStreamId, HttpMetaData metaData) {
		super(FrameType.PUSH_PROMISE);
		this.streamId = streamId;
		this.promisedStreamId = promisedStreamId;
		this.metaData = metaData;
	}

	int getStreamId() {
		return streamId;
	}

	int getPromisedStreamId() {
		return promisedStreamId;
	}

	HttpMetaData getMetaData() {
		return metaData;
	}

	override
	string toString() {
		return format("%s#%d/#%d", super.toString(), streamId, promisedStreamId);
	}
}
