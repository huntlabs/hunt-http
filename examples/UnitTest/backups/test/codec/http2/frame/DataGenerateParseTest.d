module test.codec.http2.frame;

import hunt.io.ByteBuffer;
import hunt.collection.ArrayList;
import hunt.collection.List;
import java.util.Random;

import hunt.http.codec.http.frame.Frame;
import hunt.Assert;
import hunt.util.Test;

import hunt.http.codec.http.decode.Parser;
import hunt.http.codec.http.encode.DataGenerator;
import hunt.http.codec.http.encode.HeaderGenerator;
import hunt.http.codec.http.frame.DataFrame;
import hunt.io.BufferUtils;
import hunt.http.utils.lang.Pair;

public class DataGenerateParseTest {
	private final byte[] smallContent = new byte[128];
	private final byte[] largeContent = new byte[128 * 1024];

	public DataGenerateParseTest() {
		Random random = new Random();
		random.nextBytes(smallContent);
		random.nextBytes(largeContent);
	}

	
	public void testGenerateParseNoContentNoPadding() {
		testGenerateParseContent(BufferUtils.EMPTY_BUFFER);
	}

	
	public void testGenerateParseSmallContentNoPadding() {
		testGenerateParseContent(BufferUtils.toBuffer(smallContent));
	}

	private void testGenerateParseContent(ByteBuffer content) {
		List<DataFrame> frames = testGenerateParse(content);
		Assert.assertEquals(1, frames.size());
		DataFrame frame = frames.get(0);
		Assert.assertTrue(frame.getStreamId() != 0);
		Assert.assertTrue(frame.isEndStream());
		Assert.assertEquals(content, frame.getData());
	}

	
	public void testGenerateParseLargeContent() {
		ByteBuffer content = BufferUtils.toBuffer(largeContent);
		List<DataFrame> frames = testGenerateParse(content);
		Assert.assertEquals(8, frames.size());
		ByteBuffer aggregate = BufferUtils.allocate(content.remaining());
		for (int i = 1; i <= frames.size(); ++i) {
			DataFrame frame = frames.get(i - 1);
			Assert.assertTrue(frame.getStreamId() != 0);
			Assert.assertEquals(i == frames.size(), frame.isEndStream());
			aggregate.put(frame.getData());
		}
		aggregate.flip();
		Assert.assertEquals(content, aggregate);
	}

	private List<DataFrame> testGenerateParse(ByteBuffer data) {
		DataGenerator generator = new DataGenerator(new HeaderGenerator());

		final List<DataFrame> frames = new ArrayList<>();
		Parser parser = new Parser(new Parser.Listener.Adapter() {
			override
			public void onData(DataFrame frame) {
				frames.add(frame);
			}
		}, 4096, 8192);

		// Iterate a few times to be sure generator and parser are properly
		// reset.
		for (int i = 0; i < 2; ++i) {
			ByteBuffer slice = data.slice();
			int generated = 0;
			List!(ByteBuffer) list = new ArrayList<>();
			encodeDataFrame(generator, data, slice, generated, list);

			frames.clear();
			for (ByteBuffer buffer : list) {
				parser.parse(buffer);
			}
		}

		return frames;
	}

	
	public void testGenerateParseOneByteAtATime() {
		DataGenerator generator = new DataGenerator(new HeaderGenerator());

		final List<DataFrame> frames = new ArrayList<>();
		Parser parser = new Parser(new Parser.Listener.Adapter() {
			override
			public void onData(DataFrame frame) {
				frames.add(frame);
			}
		}, 4096, 8192);

		// Iterate a few times to be sure generator and parser are properly
		// reset.
		for (int i = 0; i < 2; ++i) {
			ByteBuffer data = BufferUtils.toBuffer(largeContent);
			ByteBuffer slice = data.slice();
			int generated = 0;
			List!(ByteBuffer) list = new ArrayList<>();
			encodeDataFrame(generator, data, slice, generated, list);

			frames.clear();
			for (ByteBuffer buffer : list) {
				while (buffer.hasRemaining()) {
					parser.parse(BufferUtils.toBuffer(new byte[] { buffer.get() }));
				}
			}

			Assert.assertEquals(largeContent.length, frames.size());
		}
	}

	private void encodeDataFrame(DataGenerator generator, ByteBuffer data, ByteBuffer slice, int generated, List!(ByteBuffer) list) {
		while (true) {
            Pair<Integer, List!(ByteBuffer)> pair = generator.generateData(13, slice, true, slice.remaining());
            generated += pair.first - Frame.HEADER_LENGTH;
            list.addAll(pair.second);
            if (generated == data.remaining())
                break;
        }
	}
}
