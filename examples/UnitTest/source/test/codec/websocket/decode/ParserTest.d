module test.codec.websocket.decode.ParserTest;

import hunt.http.codec.websocket.decode.Parser;
import hunt.http.codec.websocket.exception;
import hunt.http.codec.websocket.frame;
import hunt.http.codec.websocket.model.CloseInfo;
import hunt.http.codec.websocket.model.common;
import hunt.http.codec.websocket.model.StatusCode;
import hunt.http.codec.websocket.stream.WebSocketPolicy;

import hunt.container;
import hunt.util.string;
import hunt.util.Assert;

import test.codec.websocket.utils.Hex;
import test.codec.websocket.IncomingFramesCapture;
import test.codec.websocket.UnitGenerator;
import test.codec.websocket.UnitParser;

import std.algorithm;
import std.exception;

class ParserTest {

    /**
     * Similar to the server side 5.15 testcase. A normal 2 fragment text text message, 
     * followed by another continuation.
     */
    
    void testParseCase5_15() {
        List!WebSocketFrame send = new ArrayList!WebSocketFrame();
        send.add(new TextFrame().setPayload("fragment1").setFin(false));
        send.add(new ContinuationFrame().setPayload("fragment2").setFin(true));
        send.add(new ContinuationFrame().setPayload("fragment3").setFin(false)); // bad frame
        send.add(new TextFrame().setPayload("fragment4").setFin(true));
        send.add(new CloseInfo(StatusCode.NORMAL).asFrame());

        ByteBuffer completeBuf = UnitGenerator.generate(send);
        UnitParser parser = new UnitParser();
        IncomingFramesCapture capture = new IncomingFramesCapture();
        parser.setIncomingFramesHandler(capture);

        ProtocolException expectedException = collectException!(ProtocolException)(parser.parseQuietly(completeBuf));
        assert(expectedException !is null);
        assert(expectedException.msg.canFind("CONTINUATION frame without prior !FIN"));
    }

    /**
     * Similar to the server side 5.18 testcase. Text message fragmented as 2 frames, both as opcode=TEXT
     */
    
    void testParseCase5_18() {
        List!WebSocketFrame send = new ArrayList!WebSocketFrame();
        send.add(new TextFrame().setPayload("fragment1").setFin(false));
        send.add(new TextFrame().setPayload("fragment2").setFin(true)); // bad frame, must be continuation
        send.add(new CloseInfo(StatusCode.NORMAL).asFrame());

        ByteBuffer completeBuf = UnitGenerator.generate(send);
        UnitParser parser = new UnitParser();
        IncomingFramesCapture capture = new IncomingFramesCapture();
        parser.setIncomingFramesHandler(capture);

        ProtocolException expectedException = collectException!(ProtocolException)(parser.parseQuietly(completeBuf));
        assert(expectedException !is null);
        assert(expectedException.msg.canFind("Unexpected TEXT frame"));
    }

    /**
     * Similar to the server side 5.19 testcase. text message, send in 5 frames/fragments, with 2 pings in the mix.
     */
    void testParseCase5_19() {
        List!WebSocketFrame send = new ArrayList!WebSocketFrame();
        send.add(new TextFrame().setPayload("f1").setFin(false));
        send.add(new ContinuationFrame().setPayload(",f2").setFin(false));
        send.add(new PingFrame().setPayload("pong-1"));
        send.add(new ContinuationFrame().setPayload(",f3").setFin(false));
        send.add(new ContinuationFrame().setPayload(",f4").setFin(false));
        send.add(new PingFrame().setPayload("pong-2"));
        send.add(new ContinuationFrame().setPayload(",f5").setFin(true));
        send.add(new CloseInfo(StatusCode.NORMAL).asFrame());

        ByteBuffer completeBuf = UnitGenerator.generate(send);
        UnitParser parser = new UnitParser();
        IncomingFramesCapture capture = new IncomingFramesCapture();
        parser.setIncomingFramesHandler(capture);
        parser.parseQuietly(completeBuf);

        capture.assertErrorCount(0);
        capture.assertHasFrame(OpCode.TEXT, 1);
        capture.assertHasFrame(OpCode.CONTINUATION, 4);
        capture.assertHasFrame(OpCode.CLOSE, 1);
        capture.assertHasFrame(OpCode.PING, 2);
    }

    /**
     * Similar to the server side 5.6 testcase. pong, then text, then close frames.
     */
    void testParseCase5_6() {
        List!WebSocketFrame send = new ArrayList!WebSocketFrame();
        send.add(new PongFrame().setPayload("ping"));
        send.add(new TextFrame().setPayload("hello, world"));
        send.add(new CloseInfo(StatusCode.NORMAL).asFrame());

        ByteBuffer completeBuf = UnitGenerator.generate(send);
        UnitParser parser = new UnitParser();
        IncomingFramesCapture capture = new IncomingFramesCapture();
        parser.setIncomingFramesHandler(capture);
        parser.parse(completeBuf);

        capture.assertErrorCount(0);
        capture.assertHasFrame(OpCode.TEXT, 1);
        capture.assertHasFrame(OpCode.CLOSE, 1);
        capture.assertHasFrame(OpCode.PONG, 1);
    }

    /**
     * Similar to the server side 6.2.3 testcase. Lots of small 1 byte UTF8 Text frames, 
     * representing 1 overall text message.
     */
    
    void testParseCase6_2_3() {
        string utf8 = "Hello-\uC2B5@\uC39F\uC3A4\uC3BC\uC3A0\uC3A1-UTF-8!!";
        byte[] msg = cast(byte[])utf8.dup;

        List!WebSocketFrame send = new ArrayList!WebSocketFrame();
        int textCount = 0;
        int continuationCount = 0;
        int len = cast(int)msg.length;
        bool continuation = false;
        byte[] mini;
        for (int i = 0; i < len; i++) {
            DataFrame frame = null;
            if (continuation) {
                frame = new ContinuationFrame();
                continuationCount++;
            } else {
                frame = new TextFrame();
                textCount++;
            }
            mini = new byte[1];
            mini[0] = msg[i];
            frame.setPayload(ByteBuffer.wrap(mini));
            bool isLast = (i >= (len - 1));
            frame.setFin(isLast);
            send.add(frame);
            continuation = true;
        }
        send.add(new CloseInfo(StatusCode.NORMAL).asFrame());

        ByteBuffer completeBuf = UnitGenerator.generate(send);
        UnitParser parser = new UnitParser();
        IncomingFramesCapture capture = new IncomingFramesCapture();
        parser.setIncomingFramesHandler(capture);
        parser.parse(completeBuf);

        capture.assertErrorCount(0);
        capture.assertHasFrame(OpCode.TEXT, textCount);
        capture.assertHasFrame(OpCode.CONTINUATION, continuationCount);
        capture.assertHasFrame(OpCode.CLOSE, 1);
    }

    
    void testParseNothing() {
        ByteBuffer buf = ByteBuffer.allocate(16);
        // Put nothing in the buffer.
        buf.flip();

        WebSocketPolicy policy = new WebSocketPolicy(WebSocketBehavior.SERVER);
        Parser parser = new UnitParser(policy);
        IncomingFramesCapture capture = new IncomingFramesCapture();
        parser.setIncomingFramesHandler(capture);
        parser.parse(buf);

        capture.assertNoErrors();
        Assert.assertThat("Frame Count", capture.getFrames().length, (0));
    }

    
    void testWindowedParseLargeFrame() {
        // Create frames
        byte[] payload = new byte[65536];
        payload[] = '*';

        List!WebSocketFrame frames = new ArrayList!WebSocketFrame();
        TextFrame text = new TextFrame();
        text.setPayload(ByteBuffer.wrap(payload));
        text.setMask(cast(byte[])("11223344").dup);
        frames.add(text);
        frames.add(new CloseInfo(StatusCode.NORMAL).asFrame());

        // Build up raw (network bytes) buffer
        ByteBuffer networkBytes = UnitGenerator.generate(frames);

        // Parse, in 4096 sized windows
        WebSocketPolicy policy = new WebSocketPolicy(WebSocketBehavior.SERVER);
        Parser parser = new UnitParser(policy);
        IncomingFramesCapture capture = new IncomingFramesCapture();
        parser.setIncomingFramesHandler(capture);

        while (networkBytes.remaining() > 0) {
            ByteBuffer window = networkBytes.slice();
            int windowSize = std.algorithm.min(window.remaining(), 4096);
            window.limit(windowSize);
            parser.parse(window);
            networkBytes.position(networkBytes.position() + windowSize);
        }

        capture.assertNoErrors();
        WebSocketFrame[] captureFrames = capture.getFrames();
        Assert.assertThat("Frame Count", captureFrames.length, (2));
        WebSocketFrame frame = captureFrames[0];
        Assert.assertThat("Frame[0].opcode", frame.getOpCode(), (OpCode.TEXT));
        ByteBuffer actualPayload = frame.getPayload();
        Assert.assertThat("Frame[0].payload.length", actualPayload.remaining(), (payload.length));
        // Should be all '*' characters (if masking is correct)
        for (int i = actualPayload.position(); i < actualPayload.remaining(); i++) {
            Assert.assertThat("Frame[0].payload[i]", actualPayload.get(i), (cast(byte) '*'));
        }
    }
}
