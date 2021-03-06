module hunt.http.codec.http.encode.DisconnectGenerator;

import hunt.io.ByteBuffer;
import hunt.collection.LinkedList;
import hunt.collection.List;

import hunt.http.codec.http.frame.Frame;
import hunt.http.codec.http.encode.FrameGenerator;

/**
*/
class DisconnectGenerator :FrameGenerator {
	
	private static List!(ByteBuffer) EMPTY; // = new LinkedList!(ByteBuffer)();

	static this()
	{
		EMPTY = new LinkedList!(ByteBuffer)();
	}
	
	this() {
		super(null);
	}

	override
	List!(ByteBuffer) generate(Frame frame) {
		return EMPTY;
	}

}
