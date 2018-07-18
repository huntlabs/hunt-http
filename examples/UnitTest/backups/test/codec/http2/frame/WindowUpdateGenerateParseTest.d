module test.codec.http2.frame;

import hunt.container.ByteBuffer;
import hunt.container.ArrayList;
import hunt.container.List;

import hunt.util.Assert;
import hunt.util.Test;

import hunt.http.codec.http.decode.Parser;
import hunt.http.codec.http.encode.HeaderGenerator;
import hunt.http.codec.http.encode.WindowUpdateGenerator;
import hunt.http.codec.http.frame.WindowUpdateFrame;

public class WindowUpdateGenerateParseTest {

	
	public void testGenerateParse() {
		WindowUpdateGenerator generator = new WindowUpdateGenerator(new HeaderGenerator());

		final List<WindowUpdateFrame> frames = new ArrayList<>();
		Parser parser = new Parser(new Parser.Listener.Adapter() {
			override
			public void onWindowUpdate(WindowUpdateFrame frame) {
				frames.add(frame);
			}
		}, 4096, 8192);

		int streamId = 13;
		int windowUpdate = 17;

		// Iterate a few times to be sure generator and parser are properly
		// reset.
		for (int i = 0; i < 2; ++i) {
			ByteBuffer buffer = generator.generateWindowUpdate(streamId, windowUpdate);

			frames.clear();
			while (buffer.hasRemaining()) {
				parser.parse(buffer);
			}

		}

		Assert.assertEquals(1, frames.size());
		WindowUpdateFrame frame = frames.get(0);
		Assert.assertEquals(streamId, frame.getStreamId());
		Assert.assertEquals(windowUpdate, frame.getWindowDelta());
	}

	
	public void testGenerateParseOneByteAtATime() {
		WindowUpdateGenerator generator = new WindowUpdateGenerator(new HeaderGenerator());

		final List<WindowUpdateFrame> frames = new ArrayList<>();
		Parser parser = new Parser(new Parser.Listener.Adapter() {
			override
			public void onWindowUpdate(WindowUpdateFrame frame) {
				frames.add(frame);
			}
		}, 4096, 8192);

		int streamId = 13;
		int windowUpdate = 17;

		// Iterate a few times to be sure generator and parser are properly
		// reset.
		for (int i = 0; i < 2; ++i) {
			ByteBuffer buffer = generator.generateWindowUpdate(streamId, windowUpdate);

			frames.clear();
			while (buffer.hasRemaining()) {
				parser.parse(ByteBuffer.wrap(new byte[] { buffer.get() }));
			}

			Assert.assertEquals(1, frames.size());
			WindowUpdateFrame frame = frames.get(0);
			Assert.assertEquals(streamId, frame.getStreamId());
			Assert.assertEquals(windowUpdate, frame.getWindowDelta());
		}
	}
}
