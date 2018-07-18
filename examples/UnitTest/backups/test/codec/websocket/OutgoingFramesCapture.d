module test.codec.websocket;

import hunt.http.codec.websocket.frame.Frame;
import hunt.http.codec.websocket.frame.WebSocketFrame;
import hunt.http.codec.websocket.model.OpCode;
import hunt.http.codec.websocket.model.OutgoingFrames;
import hunt.util.functional;
import hunt.container.BufferUtils;
import hunt.util.Assert;

import java.util.LinkedList;




public class OutgoingFramesCapture : OutgoingFrames {
    private LinkedList<WebSocketFrame> frames = new LinkedList<>();

    public void assertFrameCount(int expectedCount) {
        Assert.assertThat("Captured frame count", frames.size(), is(expectedCount));
    }

    public void assertHasFrame(byte op) {
        Assert.assertThat(OpCode.name(op), getFrameCount(op), greaterThanOrEqualTo(1));
    }

    public void assertHasFrame(byte op, int expectedCount) {
        Assert.assertThat(OpCode.name(op), getFrameCount(op), is(expectedCount));
    }

    public void assertHasNoFrames() {
        Assert.assertThat("Has no frames", frames.size(), is(0));
    }

    public void dump() {
        System.out.printf("Captured %d outgoing writes%n", frames.size());
        for (int i = 0; i < frames.size(); i++) {
            Frame frame = frames.get(i);
            System.out.printf("[%3d] %s%n", i, frame);
            System.out.printf("      %s%n", BufferUtils.toDetailString(frame.getPayload()));
        }
    }

    public int getFrameCount(byte op) {
        int count = 0;
        for (WebSocketFrame frame : frames) {
            if (frame.getOpCode() == op) {
                count++;
            }
        }
        return count;
    }

    public LinkedList<WebSocketFrame> getFrames() {
        return frames;
    }

    override
    public void outgoingFrame(Frame frame, Callback callback) {
        frames.add(WebSocketFrame.copy(frame));
        if (callback != null) {
            callback.succeeded();
        }
    }
}
