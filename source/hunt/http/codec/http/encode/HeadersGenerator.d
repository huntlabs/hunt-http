module hunt.http.codec.http.encode.HeadersGenerator;

import hunt.container;

import hunt.http.codec.http.frame.Flags;
import hunt.http.codec.http.frame.Frame;
import hunt.http.codec.http.frame.FrameType;
import hunt.http.codec.http.frame.HeadersFrame;
import hunt.http.codec.http.frame.PriorityFrame;
import hunt.http.codec.http.hpack.HpackEncoder;
import hunt.http.codec.http.model.MetaData;

import hunt.http.codec.http.encode.FrameGenerator;
import hunt.http.codec.http.encode.HeaderGenerator;
import hunt.http.codec.http.encode.PriorityGenerator;

import hunt.lang.exception;
import std.conv;

/**
*/
class HeadersGenerator :FrameGenerator {
	private HpackEncoder encoder;
	private int maxHeaderBlockFragment;
	private PriorityGenerator priorityGenerator;

	this(HeaderGenerator headerGenerator, HpackEncoder encoder) {
		this(headerGenerator, encoder, 0);
	}

	this(HeaderGenerator headerGenerator, HpackEncoder encoder, int maxHeaderBlockFragment) {
		super(headerGenerator);
		this.encoder = encoder;
		this.maxHeaderBlockFragment = maxHeaderBlockFragment;
		this.priorityGenerator = new PriorityGenerator(headerGenerator);
	}

	override
	List!(ByteBuffer) generate(Frame frame) {
		HeadersFrame headersFrame = cast(HeadersFrame) frame;
		return generateHeaders(headersFrame.getStreamId(), headersFrame.getMetaData(), headersFrame.getPriority(),
				headersFrame.isEndStream());
	}

	List!(ByteBuffer) generateHeaders(int streamId, MetaData metaData, PriorityFrame priority,
			bool endStream) {
		List!(ByteBuffer) list = new LinkedList!(ByteBuffer)();
		if (streamId < 0)
			throw new IllegalArgumentException("Invalid stream id: " ~ streamId.to!string());

		int flags = Flags.NONE;

		if (priority !is null)
			flags = Flags.PRIORITY;

		int maxFrameSize = getMaxFrameSize();
		ByteBuffer hpacked = ByteBuffer.allocate(maxFrameSize);
		BufferUtils.clearToFill(hpacked);
		encoder.encode(hpacked, metaData);
		int hpackedLength = hpacked.position();
		BufferUtils.flipToFlush(hpacked, 0);

		// Split into CONTINUATION frames if necessary.
		if (maxHeaderBlockFragment > 0 && hpackedLength > maxHeaderBlockFragment) {
			if (endStream)
				flags |= Flags.END_STREAM;

			int length = maxHeaderBlockFragment;
			if (priority !is null)
				length += PriorityFrame.PRIORITY_LENGTH;

			ByteBuffer header = generateHeader(FrameType.HEADERS, length, flags, streamId);
			generatePriority(header, priority);
			BufferUtils.flipToFlush(header, 0);
			list.add(header);

			hpacked.limit(maxHeaderBlockFragment);
			list.add(hpacked.slice());

			int position = maxHeaderBlockFragment;
			int limit = position + maxHeaderBlockFragment;
			while (limit < hpackedLength) {
				hpacked.position(position).limit(limit);
				header = generateHeader(FrameType.CONTINUATION, maxHeaderBlockFragment, Flags.NONE, streamId);
				BufferUtils.flipToFlush(header, 0);
				list.add(header);
				list.add(hpacked.slice());
				position += maxHeaderBlockFragment;
				limit += maxHeaderBlockFragment;
			}

			hpacked.position(position).limit(hpackedLength);
			header = generateHeader(FrameType.CONTINUATION, hpacked.remaining(), Flags.END_HEADERS, streamId);
			BufferUtils.flipToFlush(header, 0);
			list.add(header);
			list.add(hpacked);
		} else {
			flags |= Flags.END_HEADERS;
			if (endStream)
				flags |= Flags.END_STREAM;

			int length = hpackedLength;
			if (priority !is null)
				length += PriorityFrame.PRIORITY_LENGTH;

			ByteBuffer header = generateHeader(FrameType.HEADERS, length, flags, streamId);
			generatePriority(header, priority);
			BufferUtils.flipToFlush(header, 0);
			list.add(header);
			list.add(hpacked);
		}
		return list;
	}

	private void generatePriority(ByteBuffer header, PriorityFrame priority) {
		if (priority !is null) {
			priorityGenerator.generatePriorityBody(header, priority.getStreamId(), priority.getParentStreamId(),
					priority.getWeight(), priority.isExclusive());
		}
	}
}
