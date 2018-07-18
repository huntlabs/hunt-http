module hunt.http.codec.http.frame.PriorityFrame;

import hunt.http.codec.http.frame.Frame;
import hunt.http.codec.http.frame.FrameType;

import std.format;

class PriorityFrame :Frame {
	__gshared int PRIORITY_LENGTH = 5;

	private int streamId;
	private int parentStreamId;
	private int weight;
	private bool exclusive;

	this(int parentStreamId, int weight, bool exclusive) {
		this(0, parentStreamId, weight, exclusive);
	}

	this(int streamId, int parentStreamId, int weight, bool exclusive) {
		super(FrameType.PRIORITY);
		this.streamId = streamId;
		this.parentStreamId = parentStreamId;
		this.weight = weight;
		this.exclusive = exclusive;
	}

	int getStreamId() {
		return streamId;
	}

	int getParentStreamId() {
		return parentStreamId;
	}

	int getWeight() {
		return weight;
	}

	bool isExclusive() {
		return exclusive;
	}

	override
	string toString() {
		return format("%s#%d/#%d{weight=%d,exclusive=%b}", super.toString(), streamId, parentStreamId, weight,
				exclusive);
	}
}
