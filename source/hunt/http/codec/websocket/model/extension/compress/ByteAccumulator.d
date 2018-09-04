module hunt.http.codec.websocket.model.extension.compress;

import hunt.http.codec.websocket.exception.MessageTooLargeException;
import hunt.http.utils.io.BufferUtils;

import hunt.container.ByteBuffer;

import hunt.container;

class ByteAccumulator {
    private final List!(byte[]) chunks;
    private final int maxSize;
    private int length = 0;

    this(int maxOverallBufferSize) {
        this.maxSize = maxOverallBufferSize;
        chunks = new ArrayList!(byte[])();
    }

    void copyChunk(byte buf[], int offset, int length) {
        if (this.length + length > maxSize) {
            throw new MessageTooLargeException("Frame is too large");
        }

        byte copy[] = new byte[length - offset];
        // System.arraycopy(buf, offset, copy, 0, length);
        copy[0..length] = buf[offset .. offset+length];

        chunks.add(copy);
        this.length += length;
    }

    int getLength() {
        return length;
    }

    void transferTo(ByteBuffer buffer) {
        if (buffer.remaining() < length) {
            string msg = string.format("Not enough space in ByteBuffer remaining [%d] " ~ 
                "for accumulated buffers length [%d]", buffer.remaining(), length);
            throw new IllegalArgumentException(msg);
        }

        int position = buffer.position();
        foreach (byte[] chunk ; chunks) {
            buffer.put(chunk, 0, chunk.length);
        }
        BufferUtils.flipToFlush(buffer, position);
    }
}
