module test.codec.http2.frame;

import hunt.collection.ByteBuffer;
import hunt.collection.ArrayList;
import hunt.collection.List;
import java.util.Random;

import hunt.Assert;
import hunt.util.Test;

import hunt.http.codec.http.decode.Parser;
import hunt.http.codec.http.encode.HeaderGenerator;
import hunt.http.codec.http.encode.PingGenerator;
import hunt.http.codec.http.frame.PingFrame;

public class PingGenerateParseTest {

	
	public void testGenerateParse() {
		PingGenerator generator = new PingGenerator(new HeaderGenerator());

		final List<PingFrame> frames = new ArrayList<>();
		Parser parser = new Parser(new Parser.Listener.Adapter() {
			override
			public void onPing(PingFrame frame) {
				frames.add(frame);
			}
		}, 4096, 8192);

		byte[] payload = new byte[8];
		new Random().nextBytes(payload);

		// Iterate a few times to be sure generator and parser are properly
		// reset.
		for (int i = 0; i < 2; ++i) {
			ByteBuffer buffer = generator.generatePing(payload, true);

			frames.clear();

			while (buffer.hasRemaining()) {
				parser.parse(buffer);
			}

		}

		Assert.assertEquals(1, frames.size());
		PingFrame frame = frames.get(0);
		Assert.assertArrayEquals(payload, frame.getPayload());
		Assert.assertTrue(frame.isReply());
	}

	
	public void testGenerateParseOneByteAtATime() {
		PingGenerator generator = new PingGenerator(new HeaderGenerator());

		final List<PingFrame> frames = new ArrayList<>();
		Parser parser = new Parser(new Parser.Listener.Adapter() {
			override
			public void onPing(PingFrame frame) {
				frames.add(frame);
			}
		}, 4096, 8192);

		byte[] payload = new byte[8];
		new Random().nextBytes(payload);

		// Iterate a few times to be sure generator and parser are properly
		// reset.
		for (int i = 0; i < 2; ++i) {
			ByteBuffer buffer = generator.generatePing(payload, true);

			frames.clear();
			while (buffer.hasRemaining()) {
				parser.parse(ByteBuffer.wrap(new byte[] { buffer.get() }));
			}

			Assert.assertEquals(1, frames.size());
			PingFrame frame = frames.get(0);
			Assert.assertArrayEquals(payload, frame.getPayload());
			Assert.assertTrue(frame.isReply());
		}
	}

	
	public void testPayloadAsLong() {
		PingGenerator generator = new PingGenerator(new HeaderGenerator());

		final List<PingFrame> frames = new ArrayList<>();
		Parser parser = new Parser(new Parser.Listener.Adapter() {
			override
			public void onPing(PingFrame frame) {
				frames.add(frame);
			}
		}, 4096, 8192);

		PingFrame ping = new PingFrame(System.nanoTime(), true);
		List!(ByteBuffer) list = generator.generate(ping);

		for (ByteBuffer buffer : list) {
			while (buffer.hasRemaining()) {
				parser.parse(buffer);
			}
		}

		Assert.assertEquals(1, frames.size());
		PingFrame pong = frames.get(0);
		Assert.assertEquals(ping.getPayloadAsLong(), pong.getPayloadAsLong());
		Assert.assertTrue(pong.isReply());
	}
}
