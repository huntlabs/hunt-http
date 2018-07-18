module hunt.http.codec.http.frame.GoAwayFrame;

import hunt.http.codec.http.frame.Frame;
import hunt.http.codec.http.frame.FrameType;
import hunt.http.codec.http.frame.ErrorCode;

import std.format;

class GoAwayFrame :Frame {

	private int lastStreamId;
	private int error;
	private byte[] payload;

	this(int lastStreamId, int error, byte[] payload) {
		super(FrameType.GO_AWAY);
		this.lastStreamId = lastStreamId;
		this.error = error;
		this.payload = payload;
	}

	int getLastStreamId() {
		return lastStreamId;
	}

	int getError() {
		return error;
	}

	byte[] getPayload() {
		return payload;
	}

	string tryConvertPayload() {
		if (payload == null || payload.length == 0)
			return "";
		try {
			return cast(string)(payload);
		} catch (Exception x) {
			return "";
		}
	}

	override
	string toString() {
		ErrorCode errorCode = cast(ErrorCode)(error);
		return format("%s,%d/%s/%s", super.toString(), lastStreamId,
				errorCode, tryConvertPayload());
	}
}
