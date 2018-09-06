module test.codec.websocket.utils.Hex;

import hunt.util.character;
import hunt.util.exception;

import hunt.container.BufferUtils;
import hunt.container.ByteBuffer;

import std.math;
import std.format;

final class Hex {
    private enum string hexcodes = "0123456789ABCDEF";

    static byte[] asByteArray(string hstr) { 
        if ((hstr.length < 0) || ((hstr.length % 2) != 0)) {
            throw new IllegalArgumentException(format("Invalid string length of <%d>", hstr.length));
        }

        size_t size = hstr.length / 2;
        byte[] buf = new byte[size];
        byte hex;
        size_t len = hstr.length;

        int idx = cast(int) std.math.floor(((size * 2) - cast(double) len) / 2);
        for (size_t i = 0; i < len; i++) {
            hex = 0;
            if (i >= 0) {
                hex = cast(byte) (CharacterHelper.digit(hstr[i], 16) << 4);
            }
            i++;
            hex += cast(byte) (CharacterHelper.digit(hstr[i], 16));

            buf[idx] = hex;
            idx++;
        }

        return buf;
    }

    static ByteBuffer asByteBuffer(string hstr) {
        return ByteBuffer.wrap(cast(byte[])(hstr));
    }

    static string asHex(byte[] buf) {
        size_t len = buf.length;
        char[] buffer = new char[len * 2];
        for (size_t i = 0; i < len; i++) {
            buffer[i * 2] = hexcodes[(buf[i] & 0xF0) >> 4];
            buffer[(i * 2) + 1] = hexcodes[(buf[i] & 0x0F)];
        }
        return cast(string)buffer;
    }

    static string asHex(ByteBuffer buffer) {
        return asHex(BufferUtils.toArray(buffer));
    }
}
