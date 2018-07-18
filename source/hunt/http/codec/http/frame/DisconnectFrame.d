module hunt.http.codec.http.frame.DisconnectFrame;

import hunt.http.codec.http.frame.FrameType;
import hunt.http.codec.http.frame.Frame;

class DisconnectFrame :Frame {
	this() {
		super(FrameType.DISCONNECT);
	}
}
