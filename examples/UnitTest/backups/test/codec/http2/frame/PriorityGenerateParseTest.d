module test.codec.http2.frame;

import hunt.collection.ByteBuffer;
import hunt.collection.ArrayList;
import hunt.collection.List;

import hunt.Assert;
import hunt.util.Test;

import hunt.http.codec.http.decode.Parser;
import hunt.http.codec.http.encode.HeaderGenerator;
import hunt.http.codec.http.encode.PriorityGenerator;
import hunt.http.codec.http.frame.PriorityFrame;

public class PriorityGenerateParseTest {

	
	public void testGenerateParse() {
		PriorityGenerator generator = new PriorityGenerator(new HeaderGenerator());

		final List<PriorityFrame> frames = new ArrayList<>();
		Parser parser = new Parser(new Parser.Listener.Adapter() {
			override
			public void onPriority(PriorityFrame frame) {
				frames.add(frame);
			}
		}, 4096, 8192);

		int streamId = 13;
		int parentStreamId = 17;
		int weight = 256;
		bool exclusive = true;

		// Iterate a few times to be sure generator and parser are properly
		// reset.
		for (int i = 0; i < 2; ++i) {
			ByteBuffer buffer = generator.generatePriority(streamId, parentStreamId, weight, exclusive);

			frames.clear();
			while (buffer.hasRemaining()) {
				parser.parse(buffer);
			}

		}

		Assert.assertEquals(1, frames.size());
		PriorityFrame frame = frames.get(0);
		Assert.assertEquals(streamId, frame.getStreamId());
		Assert.assertEquals(parentStreamId, frame.getParentStreamId());
		Assert.assertEquals(weight, frame.getWeight());
		Assert.assertEquals(exclusive, frame.isExclusive());
	}

	
	public void testGenerateParseOneByteAtATime() {
		PriorityGenerator generator = new PriorityGenerator(new HeaderGenerator());

		final List<PriorityFrame> frames = new ArrayList<>();
		Parser parser = new Parser(new Parser.Listener.Adapter() {
			override
			public void onPriority(PriorityFrame frame) {
				frames.add(frame);
			}
		}, 4096, 8192);

		int streamId = 13;
		int parentStreamId = 17;
		int weight = 3;
		bool exclusive = true;

		// Iterate a few times to be sure generator and parser are properly
		// reset.
		for (int i = 0; i < 2; ++i) {
			ByteBuffer buffer = generator.generatePriority(streamId, parentStreamId, weight, exclusive);

			frames.clear();
			while (buffer.hasRemaining()) {
				parser.parse(ByteBuffer.wrap(new byte[] { buffer.get() }));
			}

			Assert.assertEquals(1, frames.size());
			PriorityFrame frame = frames.get(0);
			Assert.assertEquals(streamId, frame.getStreamId());
			Assert.assertEquals(parentStreamId, frame.getParentStreamId());
			Assert.assertEquals(weight, frame.getWeight());
			Assert.assertEquals(exclusive, frame.isExclusive());
		}
	}
}
