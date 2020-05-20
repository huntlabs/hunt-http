module test.codec.http2.frame;

import hunt.io.ByteBuffer;
import hunt.collection.ArrayList;
import hunt.collection.List;

import hunt.Assert;
import hunt.util.Test;

import hunt.http.codec.http.decode.Parser;
import hunt.http.codec.http.encode.HeaderGenerator;
import hunt.http.codec.http.encode.ResetGenerator;
import hunt.http.codec.http.frame.ResetFrame;

public class ResetGenerateParseTest {

	
	public void testGenerateParse() {
		ResetGenerator generator = new ResetGenerator(new HeaderGenerator());

		final List<ResetFrame> frames = new ArrayList<>();
		Parser parser = new Parser(new Parser.Listener.Adapter() {
			override
			public void onReset(ResetFrame frame) {
				frames.add(frame);
			}
		}, 4096, 8192);

		int streamId = 13;
		int error = 17;

		// Iterate a few times to be sure generator and parser are properly
		// reset.
		for (int i = 0; i < 2; ++i) {
			ByteBuffer buffer = generator.generateReset(streamId, error);

			frames.clear();

			while (buffer.hasRemaining()) {
				parser.parse(buffer);
			}

		}

		Assert.assertEquals(1, frames.size());
		ResetFrame frame = frames.get(0);
		Assert.assertEquals(streamId, frame.getStreamId());
		Assert.assertEquals(error, frame.getError());
	}

	
	public void testGenerateParseOneByteAtATime() {
		ResetGenerator generator = new ResetGenerator(new HeaderGenerator());

		final List<ResetFrame> frames = new ArrayList<>();
		Parser parser = new Parser(new Parser.Listener.Adapter() {
			override
			public void onReset(ResetFrame frame) {
				frames.add(frame);
			}
		}, 4096, 8192);

		int streamId = 13;
		int error = 17;

		// Iterate a few times to be sure generator and parser are properly
		// reset.
		for (int i = 0; i < 2; ++i) {
			ByteBuffer buffer = generator.generateReset(streamId, error);

			frames.clear();
			while (buffer.hasRemaining()) {
				parser.parse(BufferUtils.toBuffer(new byte[] { buffer.get() }));
			}

			Assert.assertEquals(1, frames.size());
			ResetFrame frame = frames.get(0);
			Assert.assertEquals(streamId, frame.getStreamId());
			Assert.assertEquals(error, frame.getError());
		}
	}
}
