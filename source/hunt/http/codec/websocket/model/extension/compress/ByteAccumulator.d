module hunt.http.codec.websocket.model.extension.compress;

import hunt.http.codec.websocket.exception.MessageTooLargeException;
import hunt.http.utils.io.BufferUtils;

import hunt.container.ByteBuffer;
import java.util.ArrayList;
import java.util.List;

class ByteAccumulator {
    private final List<byte[]> chunks = new ArrayList<>();
    private final int maxSize;
    private int length = 0;

    ByteAccumulator(int maxOverallBufferSize) {
        this.maxSize = maxOverallBufferSize;
    }

    void copyChunk(byte buf[], int offset, int length) {
        if (this.length + length > maxSize) {
            throw new MessageTooLargeException("Frame is too large");
        }

        byte copy[] = new byte[length - offset];
        System.arraycopy(buf, offset, copy, 0, length);

        chunks.add(copy);
        this.length += length;
    }

    int getLength() {
        return length;
    }

    void transferTo(ByteBuffer buffer) {
        if (buffer.remaining() < length) {
            throw new IllegalArgumentException(string.format("Not enough space in ByteBuffer remaining [%d] for accumulated buffers length [%d]",
                    buffer.remaining(), length));
        }

        int position = buffer.position();
        for (byte[] chunk : chunks) {
            buffer.put(chunk, 0, chunk.length);
        }
        BufferUtils.flipToFlush(buffer, position);
    }
}
