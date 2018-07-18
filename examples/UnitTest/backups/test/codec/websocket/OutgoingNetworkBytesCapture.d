module test.codec.websocket;

import hunt.http.codec.websocket.encode.Generator;
import hunt.http.codec.websocket.frame.Frame;
import hunt.http.codec.websocket.model.OutgoingFrames;
import hunt.util.functional;
import hunt.container.BufferUtils;
import hunt.util.TypeUtils;
import hunt.util.Assert;

import hunt.container.ByteBuffer;
import hunt.container.ArrayList;
import hunt.container.List;
import java.util.Locale;




/**
 * Capture outgoing network bytes.
 */
public class OutgoingNetworkBytesCapture : OutgoingFrames {
    private final Generator generator;
    private List!(ByteBuffer) captured;

    public OutgoingNetworkBytesCapture(Generator generator) {
        this.generator = generator;
        this.captured = new ArrayList<>();
    }

    public void assertBytes(int idx, string expectedHex) {
        Assert.assertThat("Capture index does not exist", idx, lessThan(captured.size()));
        ByteBuffer buf = captured.get(idx);
        string actualHex = TypeUtils.toHexString(BufferUtils.toArray(buf)).toUpper();
        Assert.assertThat("captured[" ~ idx ~ "]", actualHex, is(expectedHex.toUpper()));
    }

    public List!(ByteBuffer) getCaptured() {
        return captured;
    }

    override
    public void outgoingFrame(Frame frame, Callback callback) {
        ByteBuffer buf = ByteBuffer.allocate(Generator.MAX_HEADER_LENGTH + frame.getPayloadLength());
        generator.generateWholeFrame(frame, buf);
        BufferUtils.flipToFlush(buf, 0);
        captured.add(buf);
        if (callback != null) {
            callback.succeeded();
        }
    }
}
