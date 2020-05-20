module test.codec.http2.frame;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import hunt.io.ByteBuffer;
import hunt.collection.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import hunt.collection.List;
import java.util.Map;
import hunt.concurrency.atomic.AtomicInteger;

import hunt.Assert;
import hunt.util.Test;

import hunt.http.codec.http.decode.Parser;
import hunt.http.codec.http.decode.SettingsBodyParser;
import hunt.http.codec.http.encode.Http2Generator;
import hunt.http.codec.http.encode.HeaderGenerator;
import hunt.http.codec.http.encode.SettingsGenerator;
import hunt.http.codec.http.frame.ErrorCode;
import hunt.http.codec.http.frame.SettingsFrame;
import hunt.http.HttpOptions;
import hunt.http.utils.codec.Base64Utils;
import hunt.io.BufferUtils;
import hunt.util.TypeUtils;

public class SettingsGenerateParseTest {
	
	
	public void testSettingsWithBase64() {
		final HttpOptions http2Configuration = new HttpOptions();
		final Http2Generator http2Generator = new Http2Generator(http2Configuration.getMaxDynamicTableSize(), http2Configuration.getMaxHeaderBlockFragment());
		
		Map<Integer, Integer> settings = new HashMap<>();
		settings.put(SettingsFrame.HEADER_TABLE_SIZE, http2Configuration.getMaxDynamicTableSize());
		settings.put(SettingsFrame.INITIAL_WINDOW_SIZE, http2Configuration.getInitialStreamSendWindow());
		SettingsFrame settingsFrame = new SettingsFrame(settings, false);
		
		List!(ByteBuffer) byteBuffers = http2Generator.control(settingsFrame);
		writeln("buffer size: " ~ byteBuffers.size());
		try (ByteArrayOutputStream out = new ByteArrayOutputStream()) {
			for (ByteBuffer buffer : byteBuffers) {
				byte[] bufferArray = BufferUtils.toArray(buffer);
				writeln("before1:\t" ~ TypeUtils.toHexString(bufferArray));
				out.write(bufferArray);
			}
			byte[] settingsFrameBytes = out.toByteArray();
			byte[] settingsPayload = new byte[settingsFrameBytes.length - 9];
			System.arraycopy(settingsFrameBytes, 9, settingsPayload, 0, settingsPayload.length);
			
			
			string value = Base64Utils.encodeToUrlSafeString(settingsPayload);
			writeln("Settings: " ~ value);
			byte[] settingsByte = Base64Utils.decodeFromUrlSafeString(value);
			writeln("after:\t" ~ TypeUtils.toHexString(settingsByte));
			Assert.assertArrayEquals(settingsPayload, settingsByte);
			
			SettingsFrame afterSettings = SettingsBodyParser.parseBody(BufferUtils.toBuffer(settingsByte));
			writeln(afterSettings);
			Assert.assertEquals(settings, afterSettings.getSettings());
		} catch (IOException e) {
			e.printStackTrace();
		}
	}

	
	public void testGenerateParseNoSettings() {
		List<SettingsFrame> frames = testGenerateParse(Collections.<Integer, Integer> emptyMap());
		Assert.assertEquals(1, frames.size());
		SettingsFrame frame = frames.get(0);
		Assert.assertEquals(0, frame.getSettings().size());
		Assert.assertTrue(frame.isReply());
	}

	
	public void testGenerateParseSettings() {
		Map<Integer, Integer> settings1 = new HashMap<>();
		int key1 = 13;
		Integer value1 = 17;
		settings1.put(key1, value1);
		int key2 = 19;
		Integer value2 = 23;
		settings1.put(key2, value2);
		List<SettingsFrame> frames = testGenerateParse(settings1);
		Assert.assertEquals(1, frames.size());
		SettingsFrame frame = frames.get(0);
		Map<Integer, Integer> settings2 = frame.getSettings();
		Assert.assertEquals(2, settings2.size());
		Assert.assertEquals(value1, settings2.get(key1));
		Assert.assertEquals(value2, settings2.get(key2));
	}

	private List<SettingsFrame> testGenerateParse(Map<Integer, Integer> settings) {
		SettingsGenerator generator = new SettingsGenerator(new HeaderGenerator());

		final List<SettingsFrame> frames = new ArrayList<>();
		Parser parser = new Parser(new Parser.Listener.Adapter() {
			override
			public void onSettings(SettingsFrame frame) {
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

	
	public void testGenerateParseInvalidSettings() {
		SettingsGenerator generator = new SettingsGenerator(new HeaderGenerator());

		final AtomicInteger errorRef = new AtomicInteger();
		Parser parser = new Parser(new Parser.Listener.Adapter() {
			override
			public void onConnectionFailure(int error, string reason) {
				errorRef.set(error);
			}
		}, 4096, 8192);

		Map<Integer, Integer> settings1 = new HashMap<>();
		settings1.put(13, 17);
		ByteBuffer buffer = generator.generateSettings(settings1, true);
		// Modify the length of the frame to make it invalid
		ByteBuffer bytes = buffer;
		bytes.putShort(1, (short) (bytes.get!short(1) - 1));

		while (buffer.hasRemaining()) {
			parser.parse(BufferUtils.toBuffer(new byte[] { buffer.get() }));
		}

		Assert.assertEquals(ErrorCode.FRAME_SIZE_ERROR.code, errorRef.get());
	}

	
	public void testGenerateParseOneByteAtATime() {
		SettingsGenerator generator = new SettingsGenerator(new HeaderGenerator());

		final List<SettingsFrame> frames = new ArrayList<>();
		Parser parser = new Parser(new Parser.Listener.Adapter() {
			override
			public void onSettings(SettingsFrame frame) {
				frames.add(frame);
			}
		}, 4096, 8192);

		Map<Integer, Integer> settings1 = new HashMap<>();
		int key = 13;
		Integer value = 17;
		settings1.put(key, value);

		// Iterate a few times to be sure generator and parser are properly
		// reset.
		for (int i = 0; i < 2; ++i) {
			ByteBuffer buffer = generator.generateSettings(settings1, true);

			frames.clear();
			while (buffer.hasRemaining()) {
				parser.parse(BufferUtils.toBuffer(new byte[] { buffer.get() }));
			}

			Assert.assertEquals(1, frames.size());
			SettingsFrame frame = frames.get(0);
			Map<Integer, Integer> settings2 = frame.getSettings();
			Assert.assertEquals(1, settings2.size());
			Assert.assertEquals(value, settings2.get(key));
			Assert.assertTrue(frame.isReply());
		}
	}
}
