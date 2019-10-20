module test.codec.websocket.decode;

import hunt.http.codec.websocket.decode.Parser;
import hunt.http.codec.websocket.frame.PingFrame;
import hunt.http.codec.websocket.model.common;
import hunt.http.codec.websocket.model.WebSocketBehavior;
import hunt.http.WebSocketPolicy;
import hunt.collection.BufferUtils;
import hunt.Assert;
import hunt.util.Test;
import test.codec.websocket.IncomingFramesCapture;
import test.codec.websocket.UnitParser;

import hunt.collection.ByteBuffer;



public class PingPayloadParserTest {
    
    public void testBasicPingParsing() {
        ByteBuffer buf = BufferUtils.allocate(16);
        BufferUtils.clearToFill(buf);
        buf.put(new byte[]
                {cast(byte) 0x89, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f});
        BufferUtils.flipToFlush(buf, 0);

        WebSocketPolicy policy = new WebSocketPolicy(WebSocketBehavior.CLIENT);
        Parser parser = new UnitParser(policy);
        IncomingFramesCapture capture = new IncomingFramesCapture();
        parser.setIncomingFramesHandler(capture);
        parser.parse(buf);

        capture.assertNoErrors();
        capture.assertHasFrame(OpCode.PING, 1);
        PingFrame ping = (PingFrame) capture.getFrames().poll();

        string actual = BufferUtils.toUTF8String(ping.getPayload());
        Assert.assertThat("PingFrame.payload", actual, is("Hello"));
    }
}
