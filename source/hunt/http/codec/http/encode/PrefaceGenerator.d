module hunt.http.codec.http.encode.PrefaceGenerator;

import hunt.collection.ByteBuffer;
import hunt.collection.BufferUtils;
import hunt.collection.Collections;
import hunt.collection.List;

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
		return Collections.singletonList(BufferUtils.toBuffer(cast(byte[])PrefaceFrame.PREFACE_BYTES.dup));
	}
}
