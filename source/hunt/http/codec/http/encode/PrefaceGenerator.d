module hunt.http.codec.http.encode.PrefaceGenerator;

import hunt.container.ByteBuffer;
import hunt.container.Collections;
import hunt.container.List;

import hunt.http.codec.http.frame.Frame;
import hunt.http.codec.http.frame.PrefaceFrame;
import hunt.http.codec.http.encode.FrameGenerator;


/**
*/
class PrefaceGenerator :FrameGenerator {
	this() {
		super(null);
	}

	override
	List!(ByteBuffer) generate(Frame frame) {
		return Collections.singletonList(ByteBuffer.wrap(cast(byte[])PrefaceFrame.PREFACE_BYTES.dup));
	}
}
