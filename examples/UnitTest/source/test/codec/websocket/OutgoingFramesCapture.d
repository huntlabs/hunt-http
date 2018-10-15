module test.codec.websocket.OutgoingFramesCapture;

import hunt.http.codec.websocket.frame;
import hunt.http.codec.websocket.model.common;
import hunt.http.codec.websocket.model.OutgoingFrames;

import hunt.container;
import hunt.logging;

import hunt.lang.common;
import hunt.util.Assert;


class OutgoingFramesCapture : OutgoingFrames {
    private LinkedList!WebSocketFrame frames;

    this() {
        frames = new LinkedList!(WebSocketFrame)();
    }

    void assertFrameCount(int expectedCount) {
        Assert.assertThat("Captured frame count", frames.size(), (expectedCount));
    }

    void assertHasFrame(byte op) {
        // Assert.assertThat(OpCode.name(op), getFrameCount(op), greaterThanOrEqualTo(1));
        assert(getFrameCount(op) >= 1, OpCode.name(op));
    }

    void assertHasFrame(byte op, int expectedCount) {
        Assert.assertThat(OpCode.name(op), getFrameCount(op), (expectedCount));
    }

    void assertHasNoFrames() {
        Assert.assertThat("Has no frames", frames.size(), (0));
    }

    void dump() {
        tracef("Captured %d outgoing writes%n", frames.size());
        for (int i = 0; i < frames.size(); i++) {
            Frame frame = frames.get(i);
            tracef("[%3d] %s%n", i, frame);
            tracef("      %s%n", BufferUtils.toDetailString(frame.getPayload()));
        }
    }

    int getFrameCount(byte op) {
        int count = 0;
        foreach (WebSocketFrame frame ; frames) {
            if (frame.getOpCode() == op) {
                count++;
            }
        }
        return count;
    }

    LinkedList!WebSocketFrame getFrames() {
        return frames;
    }

    override
    void outgoingFrame(Frame frame, Callback callback) {
        frames.add(WebSocketFrameHelper.copy(frame));
        if (callback !is null) {
            callback.succeeded();
        }
    }
}
