module hunt.http.codec.websocket.utils;

import hunt.container.ByteBuffer;

class MaskedByteBuffer {
    private enum byte[] mask = [0x00, cast(byte) 0xF0, 0x0F, cast(byte) 0xFF];

    static void putMask(ByteBuffer buffer) {
        buffer.put(mask, 0, mask.length);
    }

    static void putPayload(ByteBuffer buffer, byte[] payload) {
        int len = payload.length;
        for (int i = 0; i < len; i++) {
            buffer.put((byte) (payload[i] ^ mask[i % 4]));
        }
    }

    static void putPayload(ByteBuffer buffer, ByteBuffer payload) {
        int len = payload.remaining();
        for (int i = 0; i < len; i++) {
            buffer.put((byte) (payload.get() ^ mask[i % 4]));
        }
    }
}
