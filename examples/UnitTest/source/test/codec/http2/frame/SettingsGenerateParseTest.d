module test.codec.http2.frame.SettingsGenerateParseTest;

import hunt.container;
// import java.util.concurrent.atomic.AtomicInteger;

import hunt.util.Assert;
// import hunt.util.Test;

import hunt.http.codec.http.decode.Parser;
import hunt.http.codec.http.decode.SettingsBodyParser;
import hunt.http.codec.http.encode.Generator;
import hunt.http.codec.http.encode.HeaderGenerator;
import hunt.http.codec.http.encode.SettingsGenerator;
import hunt.http.codec.http.frame.ErrorCode;
import hunt.http.codec.http.frame.SettingsFrame;
import hunt.http.codec.http.stream.Http2Configuration;

import hunt.logging;
import hunt.util.exception;
import hunt.util.TypeUtils;

import std.array;
import std.base64;
import std.conv;
import std.stdio;


class SettingsGenerateParseTest {
	
	void testSettingsWithBase64() {
		Http2Configuration http2Configuration = new Http2Configuration();
		Generator http2Generator = new Generator(http2Configuration.getMaxDynamicTableSize(), http2Configuration.getMaxHeaderBlockFragment());
		
		Map!(int, int) settings = new HashMap!(int, int)();
		settings.put(SettingsFrame.HEADER_TABLE_SIZE, http2Configuration.getMaxDynamicTableSize());
		settings.put(SettingsFrame.INITIAL_WINDOW_SIZE, http2Configuration.getInitialStreamSendWindow());

		SettingsFrame settingsFrame = new SettingsFrame(settings, false);
		
		List!(ByteBuffer) byteBuffers = http2Generator.control(settingsFrame);
		writeln("buffer size: " ~ byteBuffers.size().to!string());
		try  {
			// ByteArrayOutputStream ot = new ByteArrayOutputStream();
			Appender!(byte[]) ot;
			foreach (ByteBuffer buffer ; byteBuffers) {
				byte[] bufferArray = BufferUtils.toArray(buffer);
				// writeln("before1:\t" ~ TypeUtils.toHexString(bufferArray));
				writefln("before1:\t%(%02X %)" , bufferArray);
				ot.put(bufferArray);
			}
			byte[] settingsFrameBytes = ot.data; // ot.toByteArray();
			// byte[] settingsPayload = new byte[settingsFrameBytes.length - 9];
			// System.arraycopy(settingsFrameBytes, 9, settingsPayload, 0, settingsPayload.length);
			// size_t len = settingsPayload.length;
			// settingsPayload[0 .. len] = settingsFrameBytes[9 .. 9+len];
			byte[] settingsPayload = settingsFrameBytes[9 .. $];
			tracef("%(%02X %)", settingsPayload);
			
			string value = Base64URL.encode(cast(ubyte[])settingsPayload); // Base64Utils.encodeToUrlSafeString(settingsPayload);
			writeln("Settings: " ~ value);
			byte[] settingsByte = cast(byte[])Base64URL.decode(value); // Base64Utils.decodeFromUrlSafeString(value);
			// writeln("after:\t" ~ TypeUtils.toHexString(settingsByte));
			writefln("after:\t%(%02X %)" , settingsByte);
			Assert.assertArrayEquals(settingsPayload, settingsByte);
			
			SettingsFrame afterSettings = SettingsBodyParser.parseBody(BufferUtils.toBuffer(settingsByte));
			writeln(afterSettings);
			Assert.assertEquals(settings.toString(), afterSettings.getSettings().toString());

		} catch (IOException e) {
			writeln(e.toString());
		}
	}

	
	void testGenerateParseNoSettings() {
		List!(SettingsFrame) frames = parseSettings(Collections.emptyMap!(int, int)());
		Assert.assertEquals(1, frames.size());
		SettingsFrame frame = frames.get(0);
		Assert.assertEquals(0, frame.getSettings().size());
		Assert.assertTrue(frame.isReply());
	}
// vscode-fold=#
	
	void testGenerateParseSettings() {
		Map!(int, int) settings1 = new HashMap!(int, int)();
		int key1 = 13;
		int value1 = 17;
		settings1.put(key1, value1);
		int key2 = 19;
		int value2 = 23;
		settings1.put(key2, value2);
		List!(SettingsFrame) frames = parseSettings(settings1);
		Assert.assertEquals(1, frames.size());
		SettingsFrame frame = frames.get(0);
		Map!(int, int) settings2 = frame.getSettings();
		Assert.assertEquals(2, settings2.size());
		Assert.assertEquals(value1, settings2.get(key1));
		Assert.assertEquals(value2, settings2.get(key2));
	}

	private List!(SettingsFrame) parseSettings(Map!(int, int) settings) {
		SettingsGenerator generator = new SettingsGenerator(new HeaderGenerator());

		List!(SettingsFrame) frames = new ArrayList!(SettingsFrame)();
		Parser parser = new Parser(new class Parser.Listener.Adapter {
			override
			void onSettings(SettingsFrame frame) {
				frames.add(frame);
			}
		}, 4096, 8192);

		// Iterate a few times to be sure generator and parser are properly
		// reset.
		for (int i = 0; i < 2; ++i) {
			ByteBuffer buffer = generator.generateSettings(settings, true);

			frames.clear();
			while (buffer.hasRemaining()) {
				parser.parse(buffer);
			}

		}

		return frames;
	}

	
	void testGenerateParseInvalidSettings() {
		SettingsGenerator generator = new SettingsGenerator(new HeaderGenerator());

		int errorRef = 0; // new AtomicInteger();
		Parser parser = new Parser(new class Parser.Listener.Adapter {
			override
			void onConnectionFailure(int error, string reason) {
				errorRef = (error);
			}
		}, 4096, 8192);

		Map!(int, int) settings1 = new HashMap!(int, int)();
		settings1.put(13, 17);
		ByteBuffer buffer = generator.generateSettings(settings1, true);
		// Modify the length of the frame to make it invalid
		ByteBuffer bytes = buffer;
		bytes.put(1, cast(short) (bytes.get!short(1) - 1));

		while (buffer.hasRemaining()) {
			parser.parse(ByteBuffer.wrap([buffer.get()]));
		}

		Assert.assertEquals(ErrorCode.FRAME_SIZE_ERROR, errorRef);
	}

	
	void testGenerateParseOneByteAtATime() {
		SettingsGenerator generator = new SettingsGenerator(new HeaderGenerator());

		List!(SettingsFrame) frames = new ArrayList!(SettingsFrame)();
		Parser parser = new Parser(new class Parser.Listener.Adapter {
			override
			void onSettings(SettingsFrame frame) {
				frames.add(frame);
			}
		}, 4096, 8192);

		Map!(int, int) settings1 = new HashMap!(int, int)();
		int key = 13;
		int value = 17;
		settings1.put(key, value);

		// Iterate a few times to be sure generator and parser are properly
		// reset.
		for (int i = 0; i < 2; ++i) {
			ByteBuffer buffer = generator.generateSettings(settings1, true);

			frames.clear();
			while (buffer.hasRemaining()) {
				parser.parse(ByteBuffer.wrap([buffer.get() ]));
			}

			Assert.assertEquals(1, frames.size());
			SettingsFrame frame = frames.get(0);
			Map!(int, int) settings2 = frame.getSettings();
			Assert.assertEquals(1, settings2.size());
			Assert.assertEquals(value, settings2.get(key));
			Assert.assertTrue(frame.isReply());
		}
	}
}
