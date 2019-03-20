module test.codec.http2.frame;

import hunt.collection.ByteBuffer;
import hunt.collection.ArrayList;
import hunt.collection.List;

import hunt.Assert;
import hunt.util.Test;

import hunt.http.codec.http.decode.Parser;
import hunt.http.codec.http.encode.HeaderGenerator;
import hunt.http.codec.http.encode.HeadersGenerator;
import hunt.http.codec.http.frame.HeadersFrame;
import hunt.http.codec.http.frame.PriorityFrame;
import hunt.http.codec.http.hpack.HpackEncoder;
import hunt.http.codec.http.model.HostPortHttpField;
import hunt.http.codec.http.model.HttpField;
import hunt.http.codec.http.model.HttpFields;
import hunt.http.codec.http.model.HttpScheme;
import hunt.http.codec.http.model.HttpVersion;
import hunt.http.codec.http.model.MetaData;

public class HeadersGenerateParseTest {
	
	
	public void testChunkedTrialer() {
		HeadersGenerator generator = new HeadersGenerator(new HeaderGenerator(), new HpackEncoder());
		
		final List!(HeadersFrame) frames = new ArrayList<>();
		Parser parser = new Parser(new Parser.Listener.Adapter() {
			override
			public void onHeaders(HeadersFrame frame) {
				frames.add(frame);
			}
		}, 4096, 8192);
		
		
		MetaData trailer = new MetaData(null, new HttpFields());
		trailer.getFields().add("hunt-trailer", "end");
		writeln(trailer.isRequest());
		final HeadersFrame chunkedTrailerFrame = new HeadersFrame(2, trailer, null, true);
		
		List!(ByteBuffer) list = generator.generate(chunkedTrailerFrame);
		for (ByteBuffer buffer : list) {
			while (buffer.hasRemaining()) {
				parser.parse(buffer);
			}
		}
		
		Assert.assertEquals(1, frames.size());
		HeadersFrame frame = frames.get(0);
		Assert.assertEquals(2, frame.getStreamId());
		Assert.assertTrue(frame.isEndStream());
		Assert.assertEquals(false, frame.getMetaData().isRequest());
		writeln(frame.getMetaData());
		Assert.assertEquals("end", frame.getMetaData().getFields().get("hunt-trailer"));
	}

	
	public void testGenerateParse() {
		HeadersGenerator generator = new HeadersGenerator(new HeaderGenerator(), new HpackEncoder());

		int streamId = 13;
		HttpFields fields = new HttpFields();
		fields.put("Accept", "text/html");
		fields.put("User-Agent", "Jetty");
		HttpRequest metaData = new HttpRequest("GET", HttpScheme.HTTP,
				new HostPortHttpField("localhost:8080"), "/path", HttpVersion.HTTP_2, fields);

		final List!(HeadersFrame) frames = new ArrayList<>();
		Parser parser = new Parser(new Parser.Listener.Adapter() {
			override
			public void onHeaders(HeadersFrame frame) {
				frames.add(frame);
			}
		}, 4096, 8192);

		// Iterate a few times to be sure generator and parser are properly
		// reset.
		for (int i = 0; i < 2; ++i) {
			PriorityFrame priorityFrame = new PriorityFrame(streamId, 3 * streamId, 200, true);
			List!(ByteBuffer) list = generator.generateHeaders(streamId, metaData, priorityFrame, true);

			frames.clear();
			for (ByteBuffer buffer : list) {
				while (buffer.hasRemaining()) {
					parser.parse(buffer);
				}
			}

			Assert.assertEquals(1, frames.size());
			HeadersFrame frame = frames.get(0);
			Assert.assertEquals(streamId, frame.getStreamId());
			Assert.assertTrue(frame.isEndStream());
			HttpRequest request = (HttpRequest) frame.getMetaData();
			Assert.assertEquals(metaData.getMethod(), request.getMethod());
			Assert.assertEquals(metaData.getURI(), request.getURI());
			for (int j = 0; j < fields.size(); ++j) {
				HttpField field = fields.getField(j);
				Assert.assertTrue(request.getFields().contains(field));
			}
			PriorityFrame priority = frame.getPriority();
			Assert.assertNotNull(priority);
			Assert.assertEquals(priorityFrame.getStreamId(), priority.getStreamId());
			Assert.assertEquals(priorityFrame.getParentStreamId(), priority.getParentStreamId());
			Assert.assertEquals(priorityFrame.getWeight(), priority.getWeight());
			Assert.assertEquals(priorityFrame.isExclusive(), priority.isExclusive());
		}
	}

	
	public void testGenerateParseOneByteAtATime() {
		HeadersGenerator generator = new HeadersGenerator(new HeaderGenerator(), new HpackEncoder());

		final List!(HeadersFrame) frames = new ArrayList<>();
		Parser parser = new Parser(new Parser.Listener.Adapter() {
			override
			public void onHeaders(HeadersFrame frame) {
				frames.add(frame);
			}
		}, 4096, 8192);

		// Iterate a few times to be sure generator and parser are properly
		// reset.
		for (int i = 0; i < 2; ++i) {
			int streamId = 13;
			HttpFields fields = new HttpFields();
			fields.put("Accept", "text/html");
			fields.put("User-Agent", "Jetty");
			HttpRequest metaData = new HttpRequest("GET", HttpScheme.HTTP,
					new HostPortHttpField("localhost:8080"), "/path", HttpVersion.HTTP_2, fields);

			PriorityFrame priorityFrame = new PriorityFrame(streamId, 3 * streamId, 200, true);
			List!(ByteBuffer) list = generator.generateHeaders(streamId, metaData, priorityFrame, true);

			frames.clear();
			for (ByteBuffer buffer : list) {
				buffer = buffer.slice();
				while (buffer.hasRemaining()) {
					parser.parse(BufferUtils.toBuffer(new byte[] { buffer.get() }));
				}
			}

			Assert.assertEquals(1, frames.size());
			HeadersFrame frame = frames.get(0);
			Assert.assertEquals(streamId, frame.getStreamId());
			Assert.assertTrue(frame.isEndStream());
			HttpRequest request = (HttpRequest) frame.getMetaData();
			Assert.assertEquals(metaData.getMethod(), request.getMethod());
			Assert.assertEquals(metaData.getURI(), request.getURI());
			for (int j = 0; j < fields.size(); ++j) {
				HttpField field = fields.getField(j);
				Assert.assertTrue(request.getFields().contains(field));
			}
			PriorityFrame priority = frame.getPriority();
			Assert.assertNotNull(priority);
			Assert.assertEquals(priorityFrame.getStreamId(), priority.getStreamId());
			Assert.assertEquals(priorityFrame.getParentStreamId(), priority.getParentStreamId());
			Assert.assertEquals(priorityFrame.getWeight(), priority.getWeight());
			Assert.assertEquals(priorityFrame.isExclusive(), priority.isExclusive());
		}
	}
}
