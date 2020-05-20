module test.codec.websocket.IncomingFramesCapture;

import test.codec.common;

import hunt.http.Exceptions;
import hunt.http.codec.websocket.frame;
import hunt.http.WebSocketCommon;

import hunt.io.BufferUtils;
import hunt.collection.Queue;
import hunt.concurrency.LinkedBlockingQueue;
import hunt.logging;
import hunt.Assert;

import std.format;


class IncomingFramesCapture : IncomingFrames {

    private LinkedBlockingQueue!(AbstractWebSocketFrame) frames;
    private Throwable[] errors;

    this() {
        frames = new LinkedBlockingQueue!(AbstractWebSocketFrame)();
    }

    void assertErrorCount(size_t expectedCount) {
        Assert.assertThat("Captured error count", errors.length, (expectedCount));
    }

    void assertFrameCount(size_t expectedCount) {
        if (frames.size() != expectedCount) {
            // dump details
            tracef("Expected %d frame(s)%n", expectedCount);
            tracef("But actually captured %d frame(s)%n", frames.size());
            int i = 0;
            foreach (AbstractWebSocketFrame frame ; frames) {
                tracef(" [%d] Frame[%s] - %s%n", i++,
                        OpCode.name(frame.getOpCode()),
                        BufferUtils.toDetailString(frame.getPayload()));
            }
        }
        Assert.assertThat("Captured frame count", frames.size(), (expectedCount));
    }

    // void assertHasErrors(Class<? extends WebSocketException> errorType, int expectedCount) {
    //     Assert.assertThat(errorType.getSimpleName(), getErrorCount(errorType), (expectedCount));
    // }

    void assertHasFrame(byte op) {
        assert(getFrameCount(op) >= 1, OpCode.name(op));
    }

    void assertHasFrame(byte op, int expectedCount) {
        string msg = format("%s frame count", OpCode.name(op));
        Assert.assertThat(msg, getFrameCount(op), (expectedCount));
    }

    void assertHasNoFrames() {
        Assert.assertThat("Frame count", frames.size(), (0));
    }

    void assertNoErrors() {
        Assert.assertThat("Error count", errors.length, (0));
    }

    void clear() {
        frames = null;
    }

    void dump() {
        tracef("Captured %d incoming frames%n", frames.size());
        int i = 0;
        foreach (AbstractWebSocketFrame frame ; frames) {
            tracef("[%3d] %s%n", i++, frame);
            tracef("          payload: %s%n", BufferUtils.toDetailString(frame.getPayload()));
        }
    }

    // int getErrorCount(Class<? extends Throwable> errorType) {
    //     int count = 0;
    //     for (Throwable error : errors) {
    //         if (errorType.isInstance(error)) {
    //             count++;
    //         }
    //     }
    //     return count;
    // }

    Throwable[] getErrors() {
        return errors;
    }

    int getFrameCount(byte op) {
        int count = 0;
        foreach (AbstractWebSocketFrame frame ; frames) {
            if (frame.getOpCode() == op) {
                count++;
            }
        }
        return count;
    }

    Queue!AbstractWebSocketFrame getFrames() {
        return frames;
    }

    override
    void incomingError(Exception e) {
        warning("incoming error: ", e);
        errors ~= (e);
    }

    override
    void incomingFrame(WebSocketFrame frame) {
        AbstractWebSocketFrame copy = WebSocketFrameHelper.copy(frame);
        // TODO: might need to make this optional (depending on use by client vs server tests)
        // Assert.assertThat("frame.masking must be set",frame.isMasked(),(true));
        frames.add(copy);
    }

    int size() {
        return frames.size();
    }
}
