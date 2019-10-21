module test.codec.websocket.encode;

import hunt.http.codec.websocket.decode.Parser;
import hunt.http.codec.websocket.encode.Generator;
import hunt.http.codec.websocket.frame.TextFrame;
import hunt.http.codec.websocket.frame.AbstractWebSocketFrame;
import hunt.http.WebSocketCommon;
import hunt.http.WebSocketPolicy;
import hunt.collection.BufferUtils;
import hunt.Assert;
import hunt.util.Test;
import test.codec.websocket.IncomingFramesCapture;

import hunt.collection.ByteBuffer;
import java.util.Arrays;



public class GeneratorParserRoundtripTest {

    
    public void testParserAndGenerator() {
        WebSocketPolicy policy = WebSocketPolicy.newClientPolicy();
        Generator gen = new Generator(policy);
        Parser parser = new Parser(policy);
        IncomingFramesCapture capture = new IncomingFramesCapture();
        parser.setIncomingFramesHandler(capture);

        string message = "0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF";

        ByteBuffer out = BufferUtils.allocate(8192);
        // Generate Buffer
        BufferUtils.flipToFill(out);
        WebSocketFrame frame = new TextFrame().setPayload(message);
        ByteBuffer header = gen.generateHeaderBytes(frame);
        ByteBuffer payload = frame.getPayload();
        out.put(header);
        out.put(payload);

        // Parse Buffer
        BufferUtils.flipToFlush(out, 0);
        parser.parse(out);

        // Validate
        capture.assertNoErrors();
        capture.assertHasFrame(OpCode.TEXT, 1);

        TextFrame txt = (TextFrame) capture.getFrames().poll();
        Assert.assertThat("Text parsed", txt.getPayloadAsUTF8(), is(message));
    }

    
    public void testParserAndGeneratorMasked() {
        Generator gen = new Generator(WebSocketPolicy.newClientPolicy());
        Parser parser = new Parser(WebSocketPolicy.newServerPolicy());
        IncomingFramesCapture capture = new IncomingFramesCapture();
        parser.setIncomingFramesHandler(capture);

        string message = "0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF";

        ByteBuffer out = BufferUtils.allocate(8192);
        BufferUtils.flipToFill(out);
        // Setup Frame
        WebSocketFrame frame = new TextFrame().setPayload(message);

        // Add masking
        byte mask[] = new byte[4];
        Arrays.fill(mask, cast(byte) 0xFF);
        frame.setMask(mask);

        // Generate Buffer
        ByteBuffer header = gen.generateHeaderBytes(frame);
        ByteBuffer payload = frame.getPayload();
        out.put(header);
        out.put(payload);

        // Parse Buffer
        BufferUtils.flipToFlush(out, 0);
        parser.parse(out);

        // Validate
        capture.assertNoErrors();
        capture.assertHasFrame(OpCode.TEXT, 1);

        TextFrame txt = (TextFrame) capture.getFrames().poll();
        Assert.assertTrue("Text.isMasked", txt.isMasked());
        Assert.assertThat("Text parsed", txt.getPayloadAsUTF8(), is(message));
    }
}
