module hunt.http.codec.http.frame.ResetFrame;

import hunt.http.codec.http.frame.Frame;
import hunt.http.codec.http.frame.FrameType;
import hunt.http.codec.http.frame.ErrorCode;

import std.format;
import std.conv;
import std.string;

class ResetFrame :Frame {
	
	private int streamId;
	private int error;

	this(int streamId, int error) {
		super(FrameType.RST_STREAM);
		this.streamId = streamId;
		this.error = error;
	}

	int getStreamId() {
		return streamId;
	}

	int getError() {
		return error;
	}

	override
	string toString() {
		ErrorCode errorCode = cast(ErrorCode)(error);
		string reason = isValidErrorCode(errorCode) ? "error=" ~ to!string(error) : to!string(errorCode).toLower();
		return format("%s#%d{%s}", super.toString(), streamId, reason);
	}
}
