module test.codec.websocket.decode;

import hunt.http.codec.websocket.decode.Parser;
import hunt.http.codec.websocket.frame.Frame;
import hunt.http.codec.websocket.frame.WebSocketFrame;
import hunt.http.codec.websocket.model.common;
import hunt.http.codec.websocket.model.WebSocketBehavior;
import hunt.http.WebSocketPolicy;
import hunt.collection.BufferUtils;
import hunt.Assert;
import hunt.util.Test;
import test.codec.websocket.IncomingFramesCapture;
import test.codec.websocket.UnitParser;

import hunt.collection.ByteBuffer;



/**
 * Collection of Example packets as found in <a href="https://tools.ietf.org/html/rfc6455#section-5.7">RFC 6455 Examples section</a>
 */
public class RFC6455ExamplesParserTest {
    
    public void testFragmentedUnmaskedTextMessage() {
        WebSocketPolicy policy = new WebSocketPolicy(WebSocketBehavior.CLIENT);
        Parser parser = new UnitParser(policy);
        IncomingFramesCapture capture = new IncomingFramesCapture();
        parser.setIncomingFramesHandler(capture);

        ByteBuffer buf = BufferUtils.allocate(16);
        BufferUtils.clearToFill(buf);

        // Raw bytes as found in RFC 6455, Section 5.7 - Examples
        // A fragmented unmasked text message (part 1 of 2 "Hel")
        buf.put(new byte[]
                {cast(byte) 0x01, cast(byte) 0x03, 0x48, cast(byte) 0x65, 0x6c});

        // Parse #1
        BufferUtils.flipToFlush(buf, 0);
        parser.parse(buf);

        // part 2 of 2 "lo" (A continuation frame of the prior text message)
        BufferUtils.flipToFill(buf);
        buf.put(new byte[]
                {cast(byte) 0x80, 0x02, 0x6c, 0x6f});

        // Parse #2
        BufferUtils.flipToFlush(buf, 0);
        parser.parse(buf);

        capture.assertNoErrors();
        capture.assertHasFrame(OpCode.TEXT, 1);
        capture.assertHasFrame(OpCode.CONTINUATION, 1);

        WebSocketFrame txt = capture.getFrames().poll();
        string actual = BufferUtils.toUTF8String(txt.getPayload());
        Assert.assertThat("TextFrame[0].data", actual, is("Hel"));
        txt = capture.getFrames().poll();
        actual = BufferUtils.toUTF8String(txt.getPayload());
        Assert.assertThat("TextFrame[1].data", actual, is("lo"));
    }

    
    public void testSingleMaskedPongRequest() {
        ByteBuffer buf = BufferUtils.allocate(16);
        // Raw bytes as found in RFC 6455, Section 5.7 - Examples
        // Unmasked Pong request
        buf.put(new byte[]
                {cast(byte) 0x8a, cast(byte) 0x85, 0x37, cast(byte) 0xfa, 0x21, 0x3d, 0x7f, cast(byte) 0x9f, 0x4d, 0x51, 0x58});
        buf.flip();

        WebSocketPolicy policy = new WebSocketPolicy(WebSocketBehavior.SERVER);
        Parser parser = new UnitParser(policy);
        IncomingFramesCapture capture = new IncomingFramesCapture();
        parser.setIncomingFramesHandler(capture);
        parser.parse(buf);

        capture.assertNoErrors();
        capture.assertHasFrame(OpCode.PONG, 1);

        WebSocketFrame pong = capture.getFrames().poll();
        string actual = BufferUtils.toUTF8String(pong.getPayload());
        Assert.assertThat("PongFrame.payload", actual, is("Hello"));
    }

    
    public void testSingleMaskedTextMessage() {
        ByteBuffer buf = BufferUtils.allocate(16);
        // Raw bytes as found in RFC 6455, Section 5.7 - Examples
        // A single-frame masked text message
        buf.put(new byte[]
                {cast(byte) 0x81, cast(byte) 0x85, 0x37, cast(byte) 0xfa, 0x21, 0x3d, 0x7f, cast(byte) 0x9f, 0x4d, 0x51, 0x58});
        buf.flip();

        WebSocketPolicy policy = new WebSocketPolicy(WebSocketBehavior.SERVER);
        Parser parser = new UnitParser(policy);
        IncomingFramesCapture capture = new IncomingFramesCapture();
        parser.setIncomingFramesHandler(capture);
        parser.parse(buf);

        capture.assertNoErrors();
        capture.assertHasFrame(OpCode.TEXT, 1);

        WebSocketFrame txt = capture.getFrames().poll();
        string actual = BufferUtils.toUTF8String(txt.getPayload());
        Assert.assertThat("TextFrame.payload", actual, is("Hello"));
    }

    
    public void testSingleUnmasked256ByteBinaryMessage() {
        int dataSize = 256;

        ByteBuffer buf = BufferUtils.allocate(dataSize + 10);
        // Raw bytes as found in RFC 6455, Section 5.7 - Examples
        // 256 bytes binary message in a single unmasked frame
        buf.put(new byte[]
                {cast(byte) 0x82, 0x7E});
        buf.putShort((short) 0x01_00); // 16 bit size
        for (int i = 0; i < dataSize; i++) {
            buf.put(cast(byte) 0x44);
        }
        buf.flip();

        WebSocketPolicy policy = new WebSocketPolicy(WebSocketBehavior.CLIENT);
        Parser parser = new UnitParser(policy);
        IncomingFramesCapture capture = new IncomingFramesCapture();
        parser.setIncomingFramesHandler(capture);
        parser.parse(buf);

        capture.assertNoErrors();
        capture.assertHasFrame(OpCode.BINARY, 1);

        Frame bin = capture.getFrames().poll();

        Assert.assertThat("BinaryFrame.payloadLength", bin.getPayloadLength(), is(dataSize));

        ByteBuffer data = bin.getPayload();
        Assert.assertThat("BinaryFrame.payload.length", data.remaining(), is(dataSize));

        for (int i = 0; i < dataSize; i++) {
            Assert.assertThat("BinaryFrame.payload[" ~ i ~ "]", data.get(i), is(cast(byte) 0x44));
        }
    }

    
    public void testSingleUnmasked64KByteBinaryMessage() {
        int dataSize = 1024 * 64;

        ByteBuffer buf = BufferUtils.allocate((dataSize + 10));
        // Raw bytes as found in RFC 6455, Section 5.7 - Examples
        // 64 Kbytes binary message in a single unmasked frame
        buf.put(new byte[]
                {cast(byte) 0x82, 0x7F});
        buf.putLong(dataSize); // 64bit size
        for (int i = 0; i < dataSize; i++) {
            buf.put(cast(byte) 0x77);
        }
        buf.flip();

        WebSocketPolicy policy = new WebSocketPolicy(WebSocketBehavior.CLIENT);
        Parser parser = new UnitParser(policy);
        IncomingFramesCapture capture = new IncomingFramesCapture();
        parser.setIncomingFramesHandler(capture);
        parser.parse(buf);

        capture.assertNoErrors();
        capture.assertHasFrame(OpCode.BINARY, 1);

        Frame bin = capture.getFrames().poll();

        Assert.assertThat("BinaryFrame.payloadLength", bin.getPayloadLength(), is(dataSize));
        ByteBuffer data = bin.getPayload();
        Assert.assertThat("BinaryFrame.payload.length", data.remaining(), is(dataSize));

        for (int i = 0; i < dataSize; i++) {
            Assert.assertThat("BinaryFrame.payload[" ~ i ~ "]", data.get(i), is(cast(byte) 0x77));
        }
    }

    
    public void testSingleUnmaskedPingRequest() {
        ByteBuffer buf = BufferUtils.allocate(16);
        // Raw bytes as found in RFC 6455, Section 5.7 - Examples
        // Unmasked Ping request
        buf.put(new byte[]
                {cast(byte) 0x89, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f});
        buf.flip();

        WebSocketPolicy policy = new WebSocketPolicy(WebSocketBehavior.CLIENT);
        Parser parser = new UnitParser(policy);
        IncomingFramesCapture capture = new IncomingFramesCapture();
        parser.setIncomingFramesHandler(capture);
        parser.parse(buf);

        capture.assertNoErrors();
        capture.assertHasFrame(OpCode.PING, 1);

        WebSocketFrame ping = capture.getFrames().poll();
        string actual = BufferUtils.toUTF8String(ping.getPayload());
        Assert.assertThat("PingFrame.payload", actual, is("Hello"));
    }

    
    public void testSingleUnmaskedTextMessage() {
        ByteBuffer buf = BufferUtils.allocate(16);
        // Raw bytes as found in RFC 6455, Section 5.7 - Examples
        // A single-frame unmasked text message
        buf.put(new byte[]
                {cast(byte) 0x81, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f});
        buf.flip();

        WebSocketPolicy policy = new WebSocketPolicy(WebSocketBehavior.CLIENT);
        Parser parser = new UnitParser(policy);
        IncomingFramesCapture capture = new IncomingFramesCapture();
        parser.setIncomingFramesHandler(capture);
        parser.parse(buf);

        capture.assertNoErrors();
        capture.assertHasFrame(OpCode.TEXT, 1);

        WebSocketFrame txt = capture.getFrames().poll();
        string actual = BufferUtils.toUTF8String(txt.getPayload());
        Assert.assertThat("TextFrame.payload", actual, is("Hello"));
    }
}
