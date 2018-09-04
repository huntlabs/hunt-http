module test.codec.websocket.decode;

import hunt.http.codec.websocket.decode.Parser;
import hunt.http.codec.websocket.exception.MessageTooLargeException;
import hunt.http.codec.websocket.frame.WebSocketFrame;
import hunt.http.codec.websocket.model.common;
import hunt.http.codec.websocket.model.WebSocketBehavior;
import hunt.http.codec.websocket.stream.WebSocketPolicy;
import hunt.http.codec.websocket.utils.MaskedByteBuffer;
import hunt.util.Assert;
import hunt.util.Rule;
import hunt.util.Test;
import hunt.util.rules.ExpectedException;
import test.codec.websocket.IncomingFramesCapture;
import test.codec.websocket.UnitParser;

import hunt.container.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;



public class TextPayloadParserTest {
    @Rule
    public ExpectedException expectedException = ExpectedException.none();

    
    public void testFrameTooLargeDueToPolicy() {
        WebSocketPolicy policy = new WebSocketPolicy(WebSocketBehavior.SERVER);
        // Artificially small buffer/payload
        policy.setInputBufferSize(1024); // read buffer
        policy.setMaxTextMessageBufferSize(1024); // streaming buffer (not used in this test)
        policy.setMaxTextMessageSize(1024); // actual maximum text message size policy
        byte utf[] = new byte[2048];
        Arrays.fill(utf, cast(byte) 'a');

        Assert.assertThat("Must be a medium length payload", utf.length, allOf(greaterThan(0x7E), lessThan(0xFFFF)));

        ByteBuffer buf = ByteBuffer.allocate(utf.length + 8);
        buf.put(cast(byte) 0x81); // text frame, fin = true
        buf.put(cast(byte) (0x80 | 0x7E)); // 0x7E == 126 (a 2 byte payload length)
        buf.putShort((short) utf.length);
        MaskedByteBuffer.putMask(buf);
        MaskedByteBuffer.putPayload(buf, utf);
        buf.flip();

        UnitParser parser = new UnitParser(policy);
        IncomingFramesCapture capture = new IncomingFramesCapture();
        parser.setIncomingFramesHandler(capture);

        expectedException.expect(MessageTooLargeException.class);
        parser.parseQuietly(buf);
    }

    
    public void testLongMaskedText() {
        StringBuffer sb = new StringBuffer();
        for (int i = 0; i < 3500; i++) {
            sb.append("Hell\uFF4f Big W\uFF4Frld ");
        }
        sb.append(". The end.");

        string expectedText = sb.toString();
        byte utf[] = expectedText.getBytes(StandardCharsets.UTF_8);

        Assert.assertThat("Must be a long length payload", utf.length, greaterThan(0xFFFF));

        ByteBuffer buf = ByteBuffer.allocate(utf.length + 32);
        buf.put(cast(byte) 0x81); // text frame, fin = true
        buf.put(cast(byte) (0x80 | 0x7F)); // 0x7F == 127 (a 8 byte payload length)
        buf.putLong(utf.length);
        MaskedByteBuffer.putMask(buf);
        MaskedByteBuffer.putPayload(buf, utf);
        buf.flip();

        WebSocketPolicy policy = WebSocketPolicy.newServerPolicy();
        policy.setMaxTextMessageSize(100000);
        Parser parser = new UnitParser(policy);
        IncomingFramesCapture capture = new IncomingFramesCapture();
        parser.setIncomingFramesHandler(capture);
        parser.parse(buf);

        capture.assertNoErrors();
        capture.assertHasFrame(OpCode.TEXT, 1);
        WebSocketFrame txt = capture.getFrames().poll();
        Assert.assertThat("TextFrame.data", txt.getPayloadAsUTF8(), is(expectedText));
    }

    
    public void testMediumMaskedText() {
        StringBuffer sb = new StringBuffer();
        ;
        for (int i = 0; i < 14; i++) {
            sb.append("Hell\uFF4f Medium W\uFF4Frld ");
        }
        sb.append(". The end.");

        string expectedText = sb.toString();
        byte utf[] = expectedText.getBytes(StandardCharsets.UTF_8);

        Assert.assertThat("Must be a medium length payload", utf.length, allOf(greaterThan(0x7E), lessThan(0xFFFF)));

        ByteBuffer buf = ByteBuffer.allocate(utf.length + 10);
        buf.put(cast(byte) 0x81);
        buf.put(cast(byte) (0x80 | 0x7E)); // 0x7E == 126 (a 2 byte payload length)
        buf.putShort((short) utf.length);
        MaskedByteBuffer.putMask(buf);
        MaskedByteBuffer.putPayload(buf, utf);
        buf.flip();

        WebSocketPolicy policy = new WebSocketPolicy(WebSocketBehavior.SERVER);
        Parser parser = new UnitParser(policy);
        IncomingFramesCapture capture = new IncomingFramesCapture();
        parser.setIncomingFramesHandler(capture);
        parser.parse(buf);

        capture.assertNoErrors();
        capture.assertHasFrame(OpCode.TEXT, 1);
        WebSocketFrame txt = capture.getFrames().poll();
        Assert.assertThat("TextFrame.data", txt.getPayloadAsUTF8(), is(expectedText));
    }

    
    public void testShortMaskedFragmentedText() {
        string part1 = "Hello ";
        string part2 = "World";

        byte b1[] = part1.getBytes(StandardCharsets.UTF_8);
        byte b2[] = part2.getBytes(StandardCharsets.UTF_8);

        ByteBuffer buf = ByteBuffer.allocate(32);

        // part 1
        buf.put(cast(byte) 0x01); // no fin + text
        buf.put(cast(byte) (0x80 | b1.length));
        MaskedByteBuffer.putMask(buf);
        MaskedByteBuffer.putPayload(buf, b1);

        // part 2
        buf.put(cast(byte) 0x80); // fin + continuation
        buf.put(cast(byte) (0x80 | b2.length));
        MaskedByteBuffer.putMask(buf);
        MaskedByteBuffer.putPayload(buf, b2);

        buf.flip();

        WebSocketPolicy policy = new WebSocketPolicy(WebSocketBehavior.SERVER);
        Parser parser = new UnitParser(policy);
        IncomingFramesCapture capture = new IncomingFramesCapture();
        parser.setIncomingFramesHandler(capture);
        parser.parse(buf);

        capture.assertNoErrors();
        capture.assertHasFrame(OpCode.TEXT, 1);
        capture.assertHasFrame(OpCode.CONTINUATION, 1);
        WebSocketFrame txt = capture.getFrames().poll();
        Assert.assertThat("TextFrame[0].data", txt.getPayloadAsUTF8(), is(part1));
        txt = capture.getFrames().poll();
        Assert.assertThat("TextFrame[1].data", txt.getPayloadAsUTF8(), is(part2));
    }

    
    public void testShortMaskedText() {
        string expectedText = "Hello World";
        byte utf[] = expectedText.getBytes(StandardCharsets.UTF_8);

        ByteBuffer buf = ByteBuffer.allocate(24);
        buf.put(cast(byte) 0x81);
        buf.put(cast(byte) (0x80 | utf.length));
        MaskedByteBuffer.putMask(buf);
        MaskedByteBuffer.putPayload(buf, utf);
        buf.flip();

        WebSocketPolicy policy = new WebSocketPolicy(WebSocketBehavior.SERVER);
        Parser parser = new UnitParser(policy);
        IncomingFramesCapture capture = new IncomingFramesCapture();
        parser.setIncomingFramesHandler(capture);
        parser.parse(buf);

        capture.assertNoErrors();
        capture.assertHasFrame(OpCode.TEXT, 1);
        WebSocketFrame txt = capture.getFrames().poll();
        Assert.assertThat("TextFrame.data", txt.getPayloadAsUTF8(), is(expectedText));
    }

    
    public void testShortMaskedUtf8Text() {
        string expectedText = "Hell\uFF4f W\uFF4Frld";

        byte utf[] = expectedText.getBytes(StandardCharsets.UTF_8);

        ByteBuffer buf = ByteBuffer.allocate(24);
        buf.put(cast(byte) 0x81);
        buf.put(cast(byte) (0x80 | utf.length));
        MaskedByteBuffer.putMask(buf);
        MaskedByteBuffer.putPayload(buf, utf);
        buf.flip();

        WebSocketPolicy policy = new WebSocketPolicy(WebSocketBehavior.SERVER);
        Parser parser = new UnitParser(policy);
        IncomingFramesCapture capture = new IncomingFramesCapture();
        parser.setIncomingFramesHandler(capture);
        parser.parse(buf);

        capture.assertNoErrors();
        capture.assertHasFrame(OpCode.TEXT, 1);
        WebSocketFrame txt = capture.getFrames().poll();
        Assert.assertThat("TextFrame.data", txt.getPayloadAsUTF8(), is(expectedText));
    }
}
