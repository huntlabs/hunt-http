module hunt.http.codec.http.decode.HeaderBlockParser;

import hunt.collection.ByteBuffer;

import hunt.http.codec.http.hpack.HpackDecoder;
import hunt.http.codec.http.model.MetaData;
import hunt.collection.BufferUtils;

class HeaderBlockParser {
	private HpackDecoder hpackDecoder;
	private ByteBuffer blockBuffer;

	this(HpackDecoder hpackDecoder) {
		this.hpackDecoder = hpackDecoder;
	}

	MetaData parse(ByteBuffer buffer, int blockLength) {
		// We must wait for the all the bytes of the header block to arrive.
		// If they are not all available, accumulate them.
		// When all are available, decode them.

		int accumulated = blockBuffer is null ? 0 : blockBuffer.position();
		int remaining = blockLength - accumulated;

		if (buffer.remaining() < remaining) {
			if (blockBuffer is null) {
				blockBuffer = ByteBuffer.allocate(blockLength);
				BufferUtils.clearToFill(blockBuffer);
			}
			blockBuffer.put(buffer);
			return null;
		} else {
			int limit = buffer.limit();
			buffer.limit(buffer.position() + remaining);
			ByteBuffer toDecode;
			if (blockBuffer !is null) {
				blockBuffer.put(buffer);
				BufferUtils.flipToFlush(blockBuffer, 0);
				toDecode = blockBuffer;
			} else {
				toDecode = buffer;
			}

			MetaData result = hpackDecoder.decode(toDecode);
			buffer.limit(limit);
			
			if(blockBuffer !is null) {
				blockBuffer = null;
			}
			return result;
		}
	}
}
