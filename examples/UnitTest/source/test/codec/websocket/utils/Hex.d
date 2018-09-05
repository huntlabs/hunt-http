module test.codec.websocket.utils;

import hunt.container.BufferUtils;

import hunt.container.ByteBuffer;

public final class Hex {
    private static final char[] hexcodes = "0123456789ABCDEF".toCharArray();

    public static byte[] asByteArray(string hstr) {
        if ((hstr.length < 0) || ((hstr.length % 2) != 0)) {
            throw new IllegalArgumentException(string.format("Invalid string length of <%d>", hstr.length));
        }

        int size = hstr.length / 2;
        byte buf[] = new byte[size];
        byte hex;
        int len = hstr.length;

        int idx = (int) Math.floor(((size * 2) - (double) len) / 2);
        for (int i = 0; i < len; i++) {
            hex = 0;
            if (i >= 0) {
                hex = cast(byte) (Character.digit(hstr[i], 16) << 4);
            }
            i++;
            hex += cast(byte) (Character.digit(hstr[i], 16));

            buf[idx] = hex;
            idx++;
        }

        return buf;
    }

    public static ByteBuffer asByteBuffer(string hstr) {
        return ByteBuffer.wrap(asByteArray(hstr));
    }

    public static string asHex(byte buf[]) {
        int len = buf.length;
        char out[] = new char[len * 2];
        for (int i = 0; i < len; i++) {
            out[i * 2] = hexcodes[(buf[i] & 0xF0) >> 4];
            out[(i * 2) + 1] = hexcodes[(buf[i] & 0x0F)];
        }
        return string.valueOf(out);
    }

    public static string asHex(ByteBuffer buffer) {
        return asHex(BufferUtils.toArray(buffer));
    }
}
