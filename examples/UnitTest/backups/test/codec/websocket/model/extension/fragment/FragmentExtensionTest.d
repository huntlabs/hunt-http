module test.codec.websocket.model.extension.fragment;

import hunt.http.codec.websocket.frame;
import hunt.http.codec.websocket.model.ExtensionConfig;
import hunt.http.codec.websocket.model.common;
import hunt.http.codec.websocket.model.extension.fragment.FragmentExtension;
import hunt.http.codec.websocket.stream.WebSocketPolicy;
import hunt.container.BufferUtils;
import hunt.util.Assert;
import hunt.util.Test;
import test.codec.websocket.ByteBufferAssert;
import test.codec.websocket.IncomingFramesCapture;
import test.codec.websocket.OutgoingFramesCapture;

import java.io.IOException;
import hunt.container.ByteBuffer;
import java.nio.charset.StandardCharsets;
import hunt.container.ArrayList;
import java.util.LinkedList;
import hunt.container.List;



public class FragmentExtensionTest {

    /**
     * Verify that incoming frames are passed thru without modification
     */
    
    public void testIncomingFrames() {
        IncomingFramesCapture capture = new IncomingFramesCapture();

        FragmentExtension ext = new FragmentExtension();
        ext.setPolicy(WebSocketPolicy.newClientPolicy());
        ExtensionConfig config = ExtensionConfig.parse("fragment;maxLength=4");
        ext.setConfig(config);

        ext.setNextIncomingFrames(capture);

        // Quote
        List<string> quote = new ArrayList<>();
        quote.add("No amount of experimentation can ever prove me right;");
        quote.add("a single experiment can prove me wrong.");
        quote.add("-- Albert Einstein");

        // Manually create frame and pass into extension
        for (string q : quote) {
            Frame frame = new TextFrame().setPayload(q);
            ext.incomingFrame(frame);
        }

        int len = quote.size();
        capture.assertFrameCount(len);
        capture.assertHasFrame(OpCode.TEXT, len);

        string prefix;
        int i = 0;
        for (WebSocketFrame actual : capture.getFrames()) {
            prefix = "Frame[" ~ i ~ "]";

            Assert.assertThat(prefix ~ ".opcode", actual.getOpCode(), is(OpCode.TEXT));
            Assert.assertThat(prefix ~ ".fin", actual.isFin(), is(true));
            Assert.assertThat(prefix ~ ".rsv1", actual.isRsv1(), is(false));
            Assert.assertThat(prefix ~ ".rsv2", actual.isRsv2(), is(false));
            Assert.assertThat(prefix ~ ".rsv3", actual.isRsv3(), is(false));

            ByteBuffer expected = BufferUtils.toBuffer(quote.get(i), StandardCharsets.UTF_8);
            Assert.assertThat(prefix ~ ".payloadLength", actual.getPayloadLength(), is(expected.remaining()));
            ByteBufferAssert.assertEquals(prefix ~ ".payload", expected, actual.getPayload().slice());
            i++;
        }
    }

    /**
     * Incoming PING (Control Frame) should pass through extension unmodified
     */
    
    public void testIncomingPing() {
        IncomingFramesCapture capture = new IncomingFramesCapture();

        FragmentExtension ext = new FragmentExtension();
        ext.setPolicy(WebSocketPolicy.newServerPolicy());
        ExtensionConfig config = ExtensionConfig.parse("fragment;maxLength=4");
        ext.setConfig(config);

        ext.setNextIncomingFrames(capture);

        string payload = "Are you there?";
        Frame ping = new PingFrame().setPayload(payload);
        ext.incomingFrame(ping);

        capture.assertFrameCount(1);
        capture.assertHasFrame(OpCode.PING, 1);
        WebSocketFrame actual = capture.getFrames().poll();

        Assert.assertThat("Frame.opcode", actual.getOpCode(), is(OpCode.PING));
        Assert.assertThat("Frame.fin", actual.isFin(), is(true));
        Assert.assertThat("Frame.rsv1", actual.isRsv1(), is(false));
        Assert.assertThat("Frame.rsv2", actual.isRsv2(), is(false));
        Assert.assertThat("Frame.rsv3", actual.isRsv3(), is(false));

        ByteBuffer expected = BufferUtils.toBuffer(payload, StandardCharsets.UTF_8);
        Assert.assertThat("Frame.payloadLength", actual.getPayloadLength(), is(expected.remaining()));
        ByteBufferAssert.assertEquals("Frame.payload", expected, actual.getPayload().slice());
    }

    /**
     * Verify that outgoing text frames are fragmented by the maxLength configuration.
     *
     * @throws IOException on test failure
     */
    
    public void testOutgoingFramesByMaxLength() throws IOException {
        OutgoingFramesCapture capture = new OutgoingFramesCapture();

        FragmentExtension ext = new FragmentExtension();
        ext.setPolicy(WebSocketPolicy.newServerPolicy());
        ExtensionConfig config = ExtensionConfig.parse("fragment;maxLength=20");
        ext.setConfig(config);

        ext.setNextOutgoingFrames(capture);

        // Quote
        List<string> quote = new ArrayList<>();
        quote.add("No amount of experimentation can ever prove me right;");
        quote.add("a single experiment can prove me wrong.");
        quote.add("-- Albert Einstein");

        // Write quote as separate frames
        for (string section : quote) {
            Frame frame = new TextFrame().setPayload(section);
            ext.outgoingFrame(frame, null);
        }

        // Expected Frames
        List<WebSocketFrame> expectedFrames = new ArrayList<>();
        expectedFrames.add(new TextFrame().setPayload("No amount of experim").setFin(false));
        expectedFrames.add(new ContinuationFrame().setPayload("entation can ever pr").setFin(false));
        expectedFrames.add(new ContinuationFrame().setPayload("ove me right;").setFin(true));

        expectedFrames.add(new TextFrame().setPayload("a single experiment ").setFin(false));
        expectedFrames.add(new ContinuationFrame().setPayload("can prove me wrong.").setFin(true));

        expectedFrames.add(new TextFrame().setPayload("-- Albert Einstein").setFin(true));

        // capture.dump();

        int len = expectedFrames.size();
        capture.assertFrameCount(len);

        string prefix;
        LinkedList<WebSocketFrame> frames = capture.getFrames();
        for (int i = 0; i < len; i++) {
            prefix = "Frame[" ~ i ~ "]";
            WebSocketFrame actualFrame = frames.get(i);
            WebSocketFrame expectedFrame = expectedFrames.get(i);

            // tracef("actual: %s%n",actualFrame);
            // tracef("expect: %s%n",expectedFrame);

            // Validate Frame
            Assert.assertThat(prefix ~ ".opcode", actualFrame.getOpCode(), is(expectedFrame.getOpCode()));
            Assert.assertThat(prefix ~ ".fin", actualFrame.isFin(), is(expectedFrame.isFin()));
            Assert.assertThat(prefix ~ ".rsv1", actualFrame.isRsv1(), is(expectedFrame.isRsv1()));
            Assert.assertThat(prefix ~ ".rsv2", actualFrame.isRsv2(), is(expectedFrame.isRsv2()));
            Assert.assertThat(prefix ~ ".rsv3", actualFrame.isRsv3(), is(expectedFrame.isRsv3()));

            // Validate Payload
            ByteBuffer expectedData = expectedFrame.getPayload().slice();
            ByteBuffer actualData = actualFrame.getPayload().slice();

            Assert.assertThat(prefix ~ ".payloadLength", actualData.remaining(), is(expectedData.remaining()));
            ByteBufferAssert.assertEquals(prefix ~ ".payload", expectedData, actualData);
        }
    }

    /**
     * Verify that outgoing text frames are fragmented by default configuration
     *
     * @throws IOException on test failure
     */
    
    public void testOutgoingFramesDefaultConfig() throws IOException {
        OutgoingFramesCapture capture = new OutgoingFramesCapture();

        FragmentExtension ext = new FragmentExtension();
        ext.setPolicy(WebSocketPolicy.newServerPolicy());
        ExtensionConfig config = ExtensionConfig.parse("fragment");
        ext.setConfig(config);

        ext.setNextOutgoingFrames(capture);

        // Quote
        List<string> quote = new ArrayList<>();
        quote.add("No amount of experimentation can ever prove me right;");
        quote.add("a single experiment can prove me wrong.");
        quote.add("-- Albert Einstein");

        // Write quote as separate frames
        for (string section : quote) {
            Frame frame = new TextFrame().setPayload(section);
            ext.outgoingFrame(frame, null);
        }

        // Expected Frames
        List<WebSocketFrame> expectedFrames = new ArrayList<>();
        expectedFrames.add(new TextFrame().setPayload("No amount of experimentation can ever prove me right;"));
        expectedFrames.add(new TextFrame().setPayload("a single experiment can prove me wrong."));
        expectedFrames.add(new TextFrame().setPayload("-- Albert Einstein"));

        // capture.dump();

        int len = expectedFrames.size();
        capture.assertFrameCount(len);

        string prefix;
        LinkedList<WebSocketFrame> frames = capture.getFrames();
        for (int i = 0; i < len; i++) {
            prefix = "Frame[" ~ i ~ "]";
            WebSocketFrame actualFrame = frames.get(i);
            WebSocketFrame expectedFrame = expectedFrames.get(i);

            // Validate Frame
            Assert.assertThat(prefix ~ ".opcode", actualFrame.getOpCode(), is(expectedFrame.getOpCode()));
            Assert.assertThat(prefix ~ ".fin", actualFrame.isFin(), is(expectedFrame.isFin()));
            Assert.assertThat(prefix ~ ".rsv1", actualFrame.isRsv1(), is(expectedFrame.isRsv1()));
            Assert.assertThat(prefix ~ ".rsv2", actualFrame.isRsv2(), is(expectedFrame.isRsv2()));
            Assert.assertThat(prefix ~ ".rsv3", actualFrame.isRsv3(), is(expectedFrame.isRsv3()));

            // Validate Payload
            ByteBuffer expectedData = expectedFrame.getPayload().slice();
            ByteBuffer actualData = actualFrame.getPayload().slice();

            Assert.assertThat(prefix ~ ".payloadLength", actualData.remaining(), is(expectedData.remaining()));
            ByteBufferAssert.assertEquals(prefix ~ ".payload", expectedData, actualData);
        }
    }

    /**
     * Outgoing PING (Control Frame) should pass through extension unmodified
     *
     * @throws IOException on test failure
     */
    
    public void testOutgoingPing() throws IOException {
        OutgoingFramesCapture capture = new OutgoingFramesCapture();

        FragmentExtension ext = new FragmentExtension();
        ext.setPolicy(WebSocketPolicy.newServerPolicy());
        ExtensionConfig config = ExtensionConfig.parse("fragment;maxLength=4");
        ext.setConfig(config);

        ext.setNextOutgoingFrames(capture);

        string payload = "Are you there?";
        Frame ping = new PingFrame().setPayload(payload);

        ext.outgoingFrame(ping, null);

        capture.assertFrameCount(1);
        capture.assertHasFrame(OpCode.PING, 1);

        WebSocketFrame actual = capture.getFrames().getFirst();

        Assert.assertThat("Frame.opcode", actual.getOpCode(), is(OpCode.PING));
        Assert.assertThat("Frame.fin", actual.isFin(), is(true));
        Assert.assertThat("Frame.rsv1", actual.isRsv1(), is(false));
        Assert.assertThat("Frame.rsv2", actual.isRsv2(), is(false));
        Assert.assertThat("Frame.rsv3", actual.isRsv3(), is(false));

        ByteBuffer expected = BufferUtils.toBuffer(payload, StandardCharsets.UTF_8);
        Assert.assertThat("Frame.payloadLength", actual.getPayloadLength(), is(expected.remaining()));
        ByteBufferAssert.assertEquals("Frame.payload", expected, actual.getPayload().slice());
    }
}
