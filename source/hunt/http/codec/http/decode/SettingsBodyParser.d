module hunt.http.codec.http.decode.SettingsBodyParser;


import hunt.http.codec.http.decode.BodyParser;
import hunt.http.codec.http.decode.HeaderParser;
import hunt.http.codec.http.decode.Parser;

import hunt.http.codec.http.frame.ErrorCode;
import hunt.http.codec.http.frame.Flags;
import hunt.http.codec.http.frame.SettingsFrame;

import hunt.io.ByteBuffer;
import hunt.collection.HashMap;
import hunt.collection.Map;

import hunt.Exceptions;
import hunt.logging;
import std.format;

class SettingsBodyParser :BodyParser {
	// 
	private State state = State.PREPARE;
	private int cursor;
	private int length;
	private int settingId;
	private int settingValue;
	private Map!(int, int) settings;

	this(HeaderParser headerParser, Parser.Listener listener) {
		super(headerParser, listener);
	}

	protected void reset() {
		state = State.PREPARE;
		cursor = 0;
		length = 0;
		settingId = 0;
		settingValue = 0;
		settings = null;
	}

	override
	protected void emptyBody(ByteBuffer buffer) {
		onSettings(new HashMap!(int, int)());
	}

	override
	bool parse(ByteBuffer buffer) {
		while (buffer.hasRemaining()) {
			switch (state) {
			case State.PREPARE: {
				// SPEC: wrong streamId is treated as connection error.
				if (getStreamId() != 0)
					return connectionFailure(buffer, cast(int)ErrorCode.PROTOCOL_ERROR, "invalid_settings_frame");
				length = getBodyLength();
				settings = new HashMap!(int, int)();
				state = State.SETTING_ID;
				break;
			}
			case State.SETTING_ID: {
				if (buffer.remaining() >= 2) {
					settingId = buffer.get!short() & 0xFF_FF;
					state = State.SETTING_VALUE;
					length -= 2;
					if (length <= 0)
						return connectionFailure(buffer, cast(int)ErrorCode.FRAME_SIZE_ERROR, "invalid_settings_frame");
				} else {
					cursor = 2;
					settingId = 0;
					state = State.SETTING_ID_BYTES;
				}
				break;
			}
			case State.SETTING_ID_BYTES: {
				int currByte = buffer.get() & 0xFF;
				--cursor;
				settingId += currByte << (8 * cursor);
				--length;
				if (length <= 0)
					return connectionFailure(buffer, cast(int)ErrorCode.FRAME_SIZE_ERROR, "invalid_settings_frame");
				if (cursor == 0) {
					state = State.SETTING_VALUE;
				}
				break;
			}
			case State.SETTING_VALUE: {
				if (buffer.remaining() >= 4) {
					settingValue = buffer.get!int();
					version(HUNT_DEBUG)
						tracef(format("setting %d=%d", settingId, settingValue));
					settings.put(settingId, settingValue);
					state = State.SETTING_ID;
					length -= 4;
					if (length == 0)
						return onSettings(settings);
				} else {
					cursor = 4;
					settingValue = 0;
					state = State.SETTING_VALUE_BYTES;
				}
				break;
			}
			case State.SETTING_VALUE_BYTES: {
				int currByte = buffer.get() & 0xFF;
				--cursor;
				settingValue += currByte << (8 * cursor);
				--length;
				if (cursor > 0 && length <= 0)
					return connectionFailure(buffer, cast(int)ErrorCode.FRAME_SIZE_ERROR, "invalid_settings_frame");
				if (cursor == 0) {
					version(HUNT_DEBUG)
						tracef(format("setting %d=%d", settingId, settingValue));
					settings.put(settingId, settingValue);
					state = State.SETTING_ID;
					if (length == 0)
						return onSettings(settings);
				}
				break;
			}
			default: {
				throw new IllegalStateException("");
			}
			}
		}
		return false;
	}

	protected bool onSettings(Map!(int, int) settings) {
		SettingsFrame frame = new SettingsFrame(settings, hasFlag(Flags.ACK));
		reset();
		notifySettings(frame);
		return true;
	}

	static SettingsFrame parseBody(ByteBuffer buffer) {
		int bodyLength = buffer.remaining();
		// AtomicReference!(SettingsFrame) frameRef = new AtomicReference!(SettingsFrame)();
		// FIXME: Needing refactor or cleanup -@zxp at 6/28/2018, 11:31:02 AM
		// 
		SettingsFrame frameRef;

		class SettingsBodyParserEx : SettingsBodyParser
		{
			this() { super(null, null); }

			override
			protected int getStreamId() {
				return 0;
			}

			override
			protected int getBodyLength() {
				return bodyLength;
			}

			override
			protected bool onSettings(Map!(int, int) settings) {
				// frameRef.set(new SettingsFrame(settings, false));
				frameRef = new SettingsFrame(settings, false);
				return true;
			}

			override
			protected bool connectionFailure(ByteBuffer buffer, int error, string reason) {
				frameRef = null;
				return false;
			}
		}

		SettingsBodyParser parser = new SettingsBodyParserEx();
		if (bodyLength == 0)
			parser.emptyBody(buffer);
		else
			parser.parse(buffer);
		return frameRef;
	}

	private enum State {
		PREPARE, SETTING_ID, SETTING_ID_BYTES, SETTING_VALUE, SETTING_VALUE_BYTES
	}
}
