module hunt.http.codec.websocket.decode.payload;

import hunt.http.codec.websocket.exception.BadPayloadException;
import hunt.http.codec.websocket.frame.Frame;

import hunt.container.ByteBuffer;
import hunt.http.codec.websocket.frame.Frame;

import hunt.container.ByteBuffer;


/**
 * Process the payload (for demasking, validating, etc..)
 */
interface PayloadProcessor {
    /**
     * Used to process payloads for in the spec.
     *
     * @param payload the payload to process
     * @throws BadPayloadException the exception when the payload fails to validate properly
     */
    void process(ByteBuffer payload);

    void reset(Frame frame);
}

class DeMaskProcessor : PayloadProcessor {
    private byte[] maskBytes;
    private int maskInt;
    private int maskOffset;

    void process(ByteBuffer payload) {
        if (maskBytes is null) {
            return;
        }

        int maskInt = this.maskInt;
        int start = payload.position();
        int end = payload.limit();
        int offset = this.maskOffset;
        int remaining;
        while ((remaining = end - start) > 0) {
            if (remaining >= 4 && (offset & 3) == 0) {
                payload.putInt(start, payload.getInt(start) ^ maskInt);
                start += 4;
                offset += 4;
            } else {
                payload.put(start, cast(byte) (payload.get(start) ^ maskBytes[offset & 3]));
                ++start;
                ++offset;
            }
        }
        maskOffset = offset;
    }

    void reset(byte[] mask) {
        this.maskBytes = mask;
        int maskInt = 0;
        if (mask != null) {
            for (byte maskByte : mask)
                maskInt = (maskInt << 8) + (maskByte & 0xFF);
        }
        this.maskInt = maskInt;
        this.maskOffset = 0;
    }

    override
    void reset(Frame frame) {
        reset(frame.getMask());
    }
}


