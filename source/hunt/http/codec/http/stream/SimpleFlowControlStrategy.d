module hunt.http.codec.http.stream.SimpleFlowControlStrategy;

import hunt.http.codec.http.stream.AbstractFlowControlStrategy;
import hunt.http.codec.http.stream.SessionSPI;
import hunt.http.codec.http.stream.StreamSPI;

import hunt.http.codec.http.frame.Frame;
import hunt.http.codec.http.frame.WindowUpdateFrame;
import hunt.util.Common;

import hunt.logging;


/**
*/
class SimpleFlowControlStrategy :AbstractFlowControlStrategy {
    this() {
        this(DEFAULT_WINDOW_SIZE);
    }

    this(int initialStreamSendWindow) {
        super(initialStreamSendWindow);
    }

    override
    void onDataConsumed(SessionSPI session, StreamSPI stream, int length) {
        if (length <= 0)
            return;

        // This is the simple algorithm for flow control.
        // This method is called when a whole flow controlled frame has been
        // consumed.
        // We send a WindowUpdate every time, even if the frame was very small.

        WindowUpdateFrame sessionFrame = new WindowUpdateFrame(0, length);
        session.updateRecvWindow(length);
        version(HUNT_DEBUG)
            tracef("Data consumed, increased session recv window by %s for %s", length, session);

        Frame[] streamFrame = Frame.EMPTY_ARRAY;
        if (stream !is null) {
            if (stream.isRemotelyClosed()) {
                version(HUNT_DEBUG) {
                    tracef("Data consumed, ignoring update stream recv window by %s for remotely closed %s", length, stream);
                }
            } else {
                streamFrame = new Frame[1];
                streamFrame[0] = new WindowUpdateFrame(stream.getId(), length);
                stream.updateRecvWindow(length);
                version(HUNT_DEBUG)
                    tracef("Data consumed, increased stream recv window by %s for %s", length, stream);
            }
        }

        session.frames(stream, Callback.NOOP, sessionFrame, streamFrame);
    }
}
