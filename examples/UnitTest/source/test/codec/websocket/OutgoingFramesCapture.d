module test.codec.websocket.OutgoingFramesCapture;

import test.codec.common;
import hunt.http.codec.websocket.frame;
import hunt.http.WebSocketCommon;

import hunt.collection;
import hunt.logging;

import hunt.util.Common;
import hunt.Assert;
import hunt.util.Common;


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
            WebSocketFrame frame = frames.get(i);
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
    void outgoingFrame(WebSocketFrame frame, Callback callback) {
        frames.add(WebSocketFrameHelper.copy(frame));
        if (callback !is null) {
            callback.succeeded();
        }
    }
}
