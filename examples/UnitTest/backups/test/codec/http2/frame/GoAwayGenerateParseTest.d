module test.codec.http2.frame;

import hunt.io.ByteBuffer;
import hunt.collection.ArrayList;
import hunt.collection.List;
import java.util.Random;

import hunt.Assert;
import hunt.util.Test;

import hunt.http.codec.http.decode.Parser;
import hunt.http.codec.http.encode.GoAwayGenerator;
import hunt.http.codec.http.encode.HeaderGenerator;
import hunt.http.codec.http.frame.GoAwayFrame;

public class GoAwayGenerateParseTest {

	
	public void testGenerateParse() {
		GoAwayGenerator generator = new GoAwayGenerator(new HeaderGenerator());

		final List<GoAwayFrame> frames = new ArrayList<>();
		Parser parser = new Parser(new Parser.Listener.Adapter() {
			override
			public void onGoAway(GoAwayFrame frame) {
				frames.add(frame);
			}
		}, 4096, 8192);

		int lastStreamId = 13;
		int error = 17;

		// Iterate a few times to be sure generator and parser are properly
		// reset.
		for (int i = 0; i < 2; ++i) {
			ByteBuffer buffer = generator.generateGoAway(lastStreamId, error, null);

			frames.clear();
			while (buffer.hasRemaining()) {
				parser.parse(buffer);
			}
		}

		Assert.assertEquals(1, frames.size());
		GoAwayFrame frame = frames.get(0);
		Assert.assertEquals(lastStreamId, frame.getLastStreamId());
		Assert.assertEquals(error, frame.getError());
		Assert.assertNull(frame.getPayload());
	}

	
	public void testGenerateParseOneByteAtATime() {
		GoAwayGenerator generator = new GoAwayGenerator(new HeaderGenerator());

		final List<GoAwayFrame> frames = new ArrayList<>();
		Parser parser = new Parser(new Parser.Listener.Adapter() {
			override
			public void onGoAway(GoAwayFrame frame) {
				frames.add(frame);
			}
		}, 4096, 8192);

		int lastStreamId = 13;
		int error = 17;
		byte[] payload = new byte[16];
		new Random().nextBytes(payload);

		// Iterate a few times to be sure generator and parser are properly
		// reset.
		for (int i = 0; i < 2; ++i) {
			ByteBuffer buffer = generator.generateGoAway(lastStreamId, error, payload);

			frames.clear();
			while (buffer.hasRemaining()) {
				parser.parse(BufferUtils.toBuffer(new byte[] { buffer.get() }));
			}

			Assert.assertEquals(1, frames.size());
			GoAwayFrame frame = frames.get(0);
			Assert.assertEquals(lastStreamId, frame.getLastStreamId());
			Assert.assertEquals(error, frame.getError());
			Assert.assertArrayEquals(payload, frame.getPayload());
		}
	}
}
