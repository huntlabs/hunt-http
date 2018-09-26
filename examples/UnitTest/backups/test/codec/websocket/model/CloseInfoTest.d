module test.codec.websocket.model;

import hunt.http.codec.websocket.frame.CloseFrame;
import hunt.http.codec.websocket.model.CloseInfo;
import hunt.http.codec.websocket.model.common;
import hunt.string;
import hunt.container.BufferUtils;
import hunt.util.Test;

import hunt.container.ByteBuffer;

import hunt.http.codec.websocket.model.StatusCode;


import hunt.util.Assert.assertThat;

public class CloseInfoTest {
    /**
     * A test where no close is provided
     */
    
    public void testAnonymousClose() {
        CloseInfo close = new CloseInfo();
        assertThat("close.code", close.getStatusCode(), is(NO_CODE));
        assertThat("close.reason", close.getReason(), nullValue());

        CloseFrame frame = close.asFrame();
        assertThat("close frame op code", frame.getOpCode(), is(OpCode.CLOSE));
        // should result in no payload
        assertThat("close frame has payload", frame.hasPayload(), is(false));
        assertThat("close frame payload length", frame.getPayloadLength(), is(0));
    }

    /**
     * A test where NO_CODE (1005) is provided
     */
    
    public void testNoCode() {
        CloseInfo close = new CloseInfo(NO_CODE);
        assertThat("close.code", close.getStatusCode(), is(NO_CODE));
        assertThat("close.reason", close.getReason(), nullValue());

        CloseFrame frame = close.asFrame();
        assertThat("close frame op code", frame.getOpCode(), is(OpCode.CLOSE));
        // should result in no payload
        assertThat("close frame has payload", frame.hasPayload(), is(false));
        assertThat("close frame payload length", frame.getPayloadLength(), is(0));
    }

    /**
     * A test where NO_CLOSE (1006) is provided
     */
    
    public void testNoClose() {
        CloseInfo close = new CloseInfo(NO_CLOSE);
        assertThat("close.code", close.getStatusCode(), is(NO_CLOSE));
        assertThat("close.reason", close.getReason(), nullValue());

        CloseFrame frame = close.asFrame();
        assertThat("close frame op code", frame.getOpCode(), is(OpCode.CLOSE));
        // should result in no payload
        assertThat("close frame has payload", frame.hasPayload(), is(false));
        assertThat("close frame payload length", frame.getPayloadLength(), is(0));
    }

    /**
     * A test of FAILED_TLS_HANDSHAKE (1007)
     */
    
    public void testFailedTlsHandshake() {
        CloseInfo close = new CloseInfo(FAILED_TLS_HANDSHAKE);
        assertThat("close.code", close.getStatusCode(), is(FAILED_TLS_HANDSHAKE));
        assertThat("close.reason", close.getReason(), nullValue());

        CloseFrame frame = close.asFrame();
        assertThat("close frame op code", frame.getOpCode(), is(OpCode.CLOSE));
        // should result in no payload
        assertThat("close frame has payload", frame.hasPayload(), is(false));
        assertThat("close frame payload length", frame.getPayloadLength(), is(0));
    }

    /**
     * A test of NORMAL (1000)
     */
    
    public void testNormal() {
        CloseInfo close = new CloseInfo(NORMAL);
        assertThat("close.code", close.getStatusCode(), is(NORMAL));
        assertThat("close.reason", close.getReason(), nullValue());

        CloseFrame frame = close.asFrame();
        assertThat("close frame op code", frame.getOpCode(), is(OpCode.CLOSE));
        assertThat("close frame payload length", frame.getPayloadLength(), is(2));
    }

    private ByteBuffer asByteBuffer(int statusCode, string reason) {
        int len = 2; // status code length
        byte utf[] = null;
        if (StringUtils.hasText(reason)) {
            utf = StringUtils.getUtf8Bytes(reason);
            len += utf.length;
        }

        ByteBuffer buf = BufferUtils.allocate(len);
        BufferUtils.flipToFill(buf);
        buf.put(cast(byte) ((statusCode >>> 8) & 0xFF));
        buf.put(cast(byte) ((statusCode >>> 0) & 0xFF));

        if (utf != null) {
            buf.put(utf, 0, utf.length);
        }
        BufferUtils.flipToFlush(buf, 0);

        return buf;
    }

    
    public void testFromFrame() {
        ByteBuffer payload = asByteBuffer(NORMAL, null);
        assertThat("payload length", payload.remaining(), is(2));
        CloseFrame frame = new CloseFrame();
        frame.setPayload(payload);

        // create from frame
        CloseInfo close = new CloseInfo(frame);
        assertThat("close.code", close.getStatusCode(), is(NORMAL));
        assertThat("close.reason", close.getReason(), nullValue());

        // and back again
        frame = close.asFrame();
        assertThat("close frame op code", frame.getOpCode(), is(OpCode.CLOSE));
        assertThat("close frame payload length", frame.getPayloadLength(), is(2));
    }
}
