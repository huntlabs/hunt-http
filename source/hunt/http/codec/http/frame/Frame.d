module hunt.http.codec.http.frame.Frame;

import hunt.http.codec.http.frame.FrameType;
import std.format;

abstract class Frame {
	enum HEADER_LENGTH = 9;
	enum DEFAULT_MAX_LENGTH = 0x40_00;
	enum MAX_MAX_LENGTH = 0xFF_FF_FF;
	__gshared static Frame[] EMPTY_ARRAY;

	shared static this()
	{
		EMPTY_ARRAY = new Frame[0];
	}

	private FrameType type;

	protected this(FrameType type) {
		this.type = type;
	}

	FrameType getType() {
		return type;
	}

	override
	string toString() {
		return format("%s@%x", typeid(this).name, toHash());
	}
}
