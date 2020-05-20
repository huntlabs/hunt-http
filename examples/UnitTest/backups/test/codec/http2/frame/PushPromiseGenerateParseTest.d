module test.codec.http2.frame;

import hunt.io.ByteBuffer;
import hunt.collection.ArrayList;
import hunt.collection.List;

import hunt.Assert;
import hunt.util.Test;

import hunt.http.codec.http.decode.Parser;
import hunt.http.codec.http.encode.HeaderGenerator;
import hunt.http.codec.http.encode.PushPromiseGenerator;
import hunt.http.codec.http.frame.PushPromiseFrame;
import hunt.http.codec.http.hpack.HpackEncoder;
import hunt.http.codec.http.model.HostPortHttpField;
import hunt.http.HttpField;
import hunt.http.HttpFields;
import hunt.http.HttpScheme;
import hunt.http.HttpVersion;
import hunt.http.HttpMetaData;

public class PushPromiseGenerateParseTest {

	
	public void testGenerateParse() {
		PushPromiseGenerator generator = new PushPromiseGenerator(new HeaderGenerator(), new HpackEncoder());

		final List<PushPromiseFrame> frames = new ArrayList<>();
		Parser parser = new Parser(new Parser.Listener.Adapter() {
			override
			public void onPushPromise(PushPromiseFrame frame) {
				frames.add(frame);
			}
		}, 4096, 8192);

		int streamId = 13;
		int promisedStreamId = 17;
		HttpFields fields = new HttpFields();
		fields.put("Accept", "text/html");
		fields.put("User-Agent", "Jetty");
		HttpRequest metaData = new HttpRequest("GET", HttpScheme.HTTP,
				new HostPortHttpField("localhost:8080"), "/path", HttpVersion.HTTP_2, fields);

		// Iterate a few times to be sure generator and parser are properly
		// reset.
		for (int i = 0; i < 2; ++i) {
			List!(ByteBuffer) list = generator.generatePushPromise(streamId, promisedStreamId, metaData);

			frames.clear();
			for (ByteBuffer buffer : list) {
				while (buffer.hasRemaining()) {
					parser.parse(buffer);
				}
			}

			Assert.assertEquals(1, frames.size());
			PushPromiseFrame frame = frames.get(0);
			Assert.assertEquals(streamId, frame.getStreamId());
			Assert.assertEquals(promisedStreamId, frame.getPromisedStreamId());
			HttpRequest request = (HttpRequest) frame.getMetaData();
			Assert.assertEquals(metaData.getMethod(), request.getMethod());
			Assert.assertEquals(metaData.getURI(), request.getURI());
			for (int j = 0; j < fields.size(); ++j) {
				HttpField field = fields.getField(j);
				Assert.assertTrue(request.getFields().contains(field));
			}
		}
	}

	
	public void testGenerateParseOneByteAtATime() {
		PushPromiseGenerator generator = new PushPromiseGenerator(new HeaderGenerator(), new HpackEncoder());

		final List<PushPromiseFrame> frames = new ArrayList<>();
		Parser parser = new Parser(new Parser.Listener.Adapter() {
			override
			public void onPushPromise(PushPromiseFrame frame) {
				frames.add(frame);
			}
		}, 4096, 8192);

		int streamId = 13;
		int promisedStreamId = 17;
		HttpFields fields = new HttpFields();
		fields.put("Accept", "text/html");
		fields.put("User-Agent", "Jetty");
		HttpRequest metaData = new HttpRequest("GET", HttpScheme.HTTP,
				new HostPortHttpField("localhost:8080"), "/path", HttpVersion.HTTP_2, fields);

		// Iterate a few times to be sure generator and parser are properly
		// reset.
		for (int i = 0; i < 2; ++i) {
			List!(ByteBuffer) list = generator.generatePushPromise(streamId, promisedStreamId, metaData);

			frames.clear();
			for (ByteBuffer buffer : list) {
				while (buffer.hasRemaining()) {
					parser.parse(BufferUtils.toBuffer(new byte[] { buffer.get() }));
				}
			}

			Assert.assertEquals(1, frames.size());
			PushPromiseFrame frame = frames.get(0);
			Assert.assertEquals(streamId, frame.getStreamId());
			Assert.assertEquals(promisedStreamId, frame.getPromisedStreamId());
			HttpRequest request = (HttpRequest) frame.getMetaData();
			Assert.assertEquals(metaData.getMethod(), request.getMethod());
			Assert.assertEquals(metaData.getURI(), request.getURI());
			for (int j = 0; j < fields.size(); ++j) {
				HttpField field = fields.getField(j);
				Assert.assertTrue(request.getFields().contains(field));
			}
		}
	}
}
