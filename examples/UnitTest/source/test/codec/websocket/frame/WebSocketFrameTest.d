module test.codec.websocket.frame.WebSocketFrameTest;

import test.codec.websocket.utils.Hex;

import hunt.http.codec.websocket.encode;
import hunt.http.codec.websocket.frame;
import hunt.http.codec.websocket.model.CloseInfo;
import hunt.http.codec.websocket.model.StatusCode;
import hunt.http.WebSocketPolicy;

import hunt.collection.BufferUtils;
import hunt.Assert;

import hunt.collection.ByteBuffer;


class WebSocketFrameTest {

    private Generator strictGenerator;
    private Generator laxGenerator;

    private ByteBuffer generateWholeFrame(Generator generator, Frame frame) {
        ByteBuffer buf = BufferUtils.allocate(frame.getPayloadLength() + Generator.MAX_HEADER_LENGTH);
        generator.generateWholeFrame(frame, buf);
        BufferUtils.flipToFlush(buf, 0);
        return buf;
    }

    this() {
        initGenerator();
    }

    void initGenerator() {
        WebSocketPolicy policy = WebSocketPolicy.newServerPolicy();
        strictGenerator = new Generator(policy);
        laxGenerator = new Generator(policy, false);
    }

    private void assertFrameHex(string message, string expectedHex, ByteBuffer actual) {
        string actualHex = Hex.asHex(actual);
        Assert.assertThat("Generated Frame:" ~ message, actualHex, expectedHex);
    }

    
    void testLaxInvalidClose() {
        WebSocketFrame frame = new CloseFrame().setFin(false);
        ByteBuffer actual = generateWholeFrame(laxGenerator, frame);
        string expected = "0800";
        assertFrameHex("Lax Invalid Close Frame", expected, actual);
    }

    
    void testLaxInvalidPing() {
        WebSocketFrame frame = new PingFrame().setFin(false);
        ByteBuffer actual = generateWholeFrame(laxGenerator, frame);
        string expected = "0900";
        assertFrameHex("Lax Invalid Ping Frame", expected, actual);
    }

    
    void testStrictValidClose() {
        CloseInfo close = new CloseInfo(StatusCode.NORMAL);
        ByteBuffer actual = generateWholeFrame(strictGenerator, close.asFrame());
        string expected = "880203E8";
        assertFrameHex("Strict Valid Close Frame", expected, actual);
    }

    
    void testStrictValidPing() {
        WebSocketFrame frame = new PingFrame();
        ByteBuffer actual = generateWholeFrame(strictGenerator, frame);
        string expected = "8900";
        assertFrameHex("Strict Valid Ping Frame", expected, actual);
    }

    
    void testRsv1() {
        TextFrame frame = new TextFrame();
        frame.setPayload("Hi");
        frame.setRsv1(true);
        laxGenerator.setRsv1InUse(true);
        ByteBuffer actual = generateWholeFrame(laxGenerator, frame);
        string expected = "C1024869";
        assertFrameHex("Lax Text Frame with RSV1", expected, actual);
    }

    
    void testRsv2() {
        TextFrame frame = new TextFrame();
        frame.setPayload("Hi");
        frame.setRsv2(true);
        laxGenerator.setRsv2InUse(true);
        ByteBuffer actual = generateWholeFrame(laxGenerator, frame);
        string expected = "A1024869";
        assertFrameHex("Lax Text Frame with RSV2", expected, actual);
    }

    
    void testRsv3() {
        TextFrame frame = new TextFrame();
        frame.setPayload("Hi");
        frame.setRsv3(true);
        laxGenerator.setRsv3InUse(true);
        ByteBuffer actual = generateWholeFrame(laxGenerator, frame);
        string expected = "91024869";
        assertFrameHex("Lax Text Frame with RSV3", expected, actual);
    }
}
