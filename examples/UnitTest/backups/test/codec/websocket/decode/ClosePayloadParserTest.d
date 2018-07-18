module test.codec.websocket.decode;

import hunt.http.codec.websocket.decode.Parser;
import hunt.http.codec.websocket.model.CloseInfo;
import hunt.http.codec.websocket.model.OpCode;
import hunt.http.codec.websocket.model.StatusCode;
import hunt.http.codec.websocket.model.WebSocketBehavior;
import hunt.http.codec.websocket.stream.WebSocketPolicy;
import hunt.http.codec.websocket.utils.MaskedByteBuffer;
import hunt.util.Assert;
import hunt.util.Test;
import test.codec.websocket.IncomingFramesCapture;
import test.codec.websocket.UnitParser;

import hunt.container.ByteBuffer;
import java.nio.charset.StandardCharsets;



public class ClosePayloadParserTest {
    
    public void testGameOver() {
        string expectedReason = "Game Over";

        byte utf[] = expectedReason.getBytes(StandardCharsets.UTF_8);
        ByteBuffer payload = ByteBuffer.allocate(utf.length + 2);
        payload.putChar((char) StatusCode.NORMAL);
        payload.put(utf, 0, utf.length);
        payload.flip();

        ByteBuffer buf = ByteBuffer.allocate(24);
        buf.put(cast(byte) (0x80 | OpCode.CLOSE)); // fin + close
        buf.put(cast(byte) (0x80 | payload.remaining()));
        MaskedByteBuffer.putMask(buf);
        MaskedByteBuffer.putPayload(buf, payload);
        buf.flip();

        WebSocketPolicy policy = new WebSocketPolicy(WebSocketBehavior.SERVER);
        Parser parser = new UnitParser(policy);
        IncomingFramesCapture capture = new IncomingFramesCapture();
        parser.setIncomingFramesHandler(capture);
        parser.parse(buf);

        capture.assertNoErrors();
        capture.assertHasFrame(OpCode.CLOSE, 1);
        CloseInfo close = new CloseInfo(capture.getFrames().poll());
        Assert.assertThat("CloseFrame.statusCode", close.getStatusCode(), is(StatusCode.NORMAL));
        Assert.assertThat("CloseFrame.data", close.getReason(), is(expectedReason));
    }
}
