module test.codec.websocket.UnitParser;

import hunt.http.codec.websocket.decode.Parser;
import hunt.http.codec.websocket.stream.WebSocketPolicy;

import hunt.collection.ByteBuffer;
import hunt.collection.BufferUtils;

import std.algorithm;

class UnitParser : Parser {
    this() {
        this(WebSocketPolicy.newServerPolicy());
    }

    this(WebSocketPolicy policy) {
        super(policy);
    }

    private void parsePartial(ByteBuffer buf, int numBytes) {
        int len = std.algorithm.min(numBytes, buf.remaining());
        byte[] arr = new byte[len];
        buf.get(arr, 0, len);
        this.parse(BufferUtils.toBuffer(arr));
    }

    /**
     * Parse a buffer, but do so in a quiet fashion, squelching stacktraces if encountered.
     * <p>
     * Use if you know the parse will cause an exception and just don't wnat to make the test console all noisy.
     *
     * @param buf the buffer to parse
     */
    void parseQuietly(ByteBuffer buf) {
        parse(buf);
    }

    void parseSlowly(ByteBuffer buf, int segmentSize) {
        while (buf.remaining() > 0) {
            parsePartial(buf, segmentSize);
        }
    }
}
