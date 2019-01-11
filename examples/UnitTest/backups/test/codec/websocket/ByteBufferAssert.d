module test.codec.websocket;

import hunt.collection.BufferUtils;

import hunt.collection.ByteBuffer;



import hunt.Assert.assertThat;

public class ByteBufferAssert {
    public static void assertEquals(string message, byte[] expected, byte[] actual) {
        assertThat(message ~ " byte[].length", actual.length, is(expected.length));
        int len = expected.length;
        for (int i = 0; i < len; i++) {
            assertThat(message ~ " byte[" ~ i ~ "]", actual[i], is(expected[i]));
        }
    }

    public static void assertEquals(string message, ByteBuffer expectedBuffer, ByteBuffer actualBuffer) {
        if (expectedBuffer == null) {
            assertThat(message, actualBuffer, nullValue());
        } else {
            byte expectedBytes[] = BufferUtils.toArray(expectedBuffer);
            byte actualBytes[] = BufferUtils.toArray(actualBuffer);
            assertEquals(message, expectedBytes, actualBytes);
        }
    }

    public static void assertEquals(string message, string expectedString, ByteBuffer actualBuffer) {
        string actualString = BufferUtils.toString(actualBuffer);
        assertThat(message, actualString, is(expectedString));
    }

    public static void assertSize(string message, int expectedSize, ByteBuffer buffer) {
        if ((expectedSize == 0) && (buffer == null)) {
            return;
        }
        assertThat(message ~ " buffer.remaining", buffer.remaining(), is(expectedSize));
    }
}
