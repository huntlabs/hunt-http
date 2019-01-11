module hunt.http.codec.http.frame.SettingsFrame;

import hunt.http.codec.http.frame.Frame;
import hunt.http.codec.http.frame.FrameType;

import hunt.collection.Map;

import std.format;

class SettingsFrame : Frame {
	enum HEADER_TABLE_SIZE = 1;
	enum ENABLE_PUSH = 2;
	enum MAX_CONCURRENT_STREAMS = 3;
	enum INITIAL_WINDOW_SIZE = 4;
	enum MAX_FRAME_SIZE = 5;
	enum MAX_HEADER_LIST_SIZE = 6;

	private Map!(int, int) settings;
	private bool reply;

	this(Map!(int, int) settings, bool reply) {
		super(FrameType.SETTINGS);
		this.settings = settings;
		this.reply = reply;
	}

	Map!(int, int) getSettings() {
		return settings;
	}

	bool isReply() {
		return reply;
	}

	override
	string toString() {
		return format("%s,reply=%b:%s", super.toString(), reply, settings);
	}
}
