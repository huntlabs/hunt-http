module hunt.http.codec.http.stream.BufferingFlowControlStrategy;

import hunt.http.codec.http.stream.AbstractFlowControlStrategy;
import hunt.http.codec.http.stream.StreamSPI;
import hunt.http.codec.http.stream.SessionSPI;

import hunt.http.codec.http.frame.Frame;
import hunt.http.codec.http.frame.WindowUpdateFrame;
import hunt.util.functional;

import hunt.container.Map;

import hunt.logging;
import std.format;

/**
 * <p>
 * A flow control strategy that accumulates updates and emits window control
 * frames when the accumulated value reaches a threshold.
 * </p>
 * <p>
 * The sender flow control window is represented in the receiver as two buckets:
 * a bigger bucket, initially full, that is drained when data is received, and a
 * smaller bucket, initially empty, that is filled when data is consumed. Only
 * the smaller bucket can refill the bigger bucket.
 * </p>
 * <p>
 * The smaller bucket is defined as a fraction of the bigger bucket.
 * </p>
 * <p>
 * For a more visual representation, see the
 * <a href="http://en.wikipedia.org/wiki/Shishi-odoshi">rocking bamboo
 * fountain</a>.
 * </p>
 * <p>
 * The algorithm works in this way.
 * </p>
 * <p>
 * The initial bigger bucket (BB) capacity is 100, and let's imagine the smaller
 * bucket (SB) being 40% of the bigger bucket: 40.
 * </p>
 * <p>
 * The receiver receives a data frame of 60, so now BB=40; the data frame is
 * passed to the application that consumes 25, so now SB=25. Since SB is not
 * full, no window control frames are emitted.
 * </p>
 * <p>
 * The application consumes other 20, so now SB=45. Since SB is full, its 45 are
 * transferred to BB, which is now BB=85, and a window control frame is sent
 * with delta=45.
 * </p>
 * <p>
 * The application consumes the remaining 15, so now SB=15, and no window
 * control frame is emitted.
 * </p>
 */
class BufferingFlowControlStrategy :AbstractFlowControlStrategy {
    // private AtomicInteger maxSessionRecvWindow = new AtomicInteger(DEFAULT_WINDOW_SIZE);
    // private AtomicInteger sessionLevel = new AtomicInteger();
    // private AtomicInteger[StreamSPI] streamLevels = new ConcurrentHashMap<>();
    private int maxSessionRecvWindow;
    private int sessionLevel;
    private int[StreamSPI] streamLevels; // = new ConcurrentHashMap<>();
    private float bufferRatio;

    this(float bufferRatio) {
        this(DEFAULT_WINDOW_SIZE, bufferRatio);
    }

    this(int initialStreamSendWindow, float bufferRatio) {
        super(initialStreamSendWindow);
        this.bufferRatio = bufferRatio;
    }

    float getBufferRatio() {
        return bufferRatio;
    }

    void setBufferRatio(float bufferRatio) {
        this.bufferRatio = bufferRatio;
    }

    override
    void onStreamCreated(StreamSPI stream) {
        super.onStreamCreated(stream);
        streamLevels[stream] = 0;
    }

    override
    void onStreamDestroyed(StreamSPI stream) {
        streamLevels.remove(stream);
        super.onStreamDestroyed(stream);
    }

    override
    void onDataConsumed(SessionSPI session, StreamSPI stream, int length) {
        if (length <= 0) {
            return;
        }
        float ratio = bufferRatio;

        WindowUpdateFrame windowFrame = null;
        sessionLevel += length;
        int level = sessionLevel;
        int maxLevel = cast(int) (maxSessionRecvWindow * ratio);
        if (level > maxLevel) {
            // if (sessionLevel.compareAndSet(level, 0)) 
            if(sessionLevel == level)
            {
                sessionLevel = 0;
                session.updateRecvWindow(level);
                version(HuntDebugMode) {
                    tracef("Data consumed, %s bytes, updated session recv window by %s/%s for %s", length, level,
                            maxLevel, session);
                }
                windowFrame = new WindowUpdateFrame(0, level);
            } else {
                version(HuntDebugMode) {
                    tracef("Data consumed, %s bytes, concurrent session recv window level %s/%s for %s", length, sessionLevel, maxLevel, session);
                }
            }
        } else {
            version(HuntDebugMode) {
                tracef("Data consumed, %s bytes, session recv window level %s/%s for %s", length, level, maxLevel, session);
            }
        }

        Frame[] windowFrames = Frame.EMPTY_ARRAY;
        if (stream !is null) {
            if (stream.isRemotelyClosed()) {
                version(HuntDebugMode) {
                    tracef("Data consumed, %s bytes, ignoring update stream recv window for remotely closed %s", length, stream);
                }
            } else {
                int streamLevel = streamLevels[stream];
                // if (streamLevel != null) {
                    streamLevel += length;
                    level = streamLevel; // streamLevel.addAndGet(length);
                    maxLevel = cast(int) (getInitialStreamRecvWindow() * ratio);
                    if (level > maxLevel) {
                        level = streamLevel; streamLevel = 0;
                        stream.updateRecvWindow(level);
                        version(HuntDebugMode) {
                            tracef("Data consumed, %s bytes, updated stream recv window by %s/%s for %s", length, level, maxLevel, stream);
                        }
                        WindowUpdateFrame frame = new WindowUpdateFrame(stream.getId(), level);
                        if (windowFrame is null) {
                            windowFrame = frame;
                        } else {
                            windowFrames = [frame];
                        }
                    } else {
                        version(HuntDebugMode) {
                            tracef("Data consumed, %s bytes, stream recv window level %s/%s for %s", length, level, maxLevel, stream);
                        }
                    }
                // }
            }
        }

        if (windowFrame !is null) {
            session.frames(stream, Callback.NOOP, windowFrame, windowFrames);
        }
    }

    override
    void windowUpdate(SessionSPI session, StreamSPI stream, WindowUpdateFrame frame) {
        super.windowUpdate(session, stream, frame);

        // Window updates cannot be negative.
        // The SettingsFrame.INITIAL_WINDOW_SIZE setting
        // only influences the *stream* window size.
        // Therefore the session window can only be enlarged,
        // and here we keep track of its max value.

        // Updating the max session recv window is done here
        // so that if a peer decides to send an unilateral
        // window update to enlarge the session window,
        // without the corresponding data consumption, here
        // we can track it.
        // Note that it is not perfect, since there is a time
        // window between the session recv window being updated
        // before the window update frame is sent, and the
        // invocation of this method: in between data may arrive
        // and reduce the session recv window size.
        // But eventually the max value will be seen.

        // Note that we cannot avoid the time window described
        // above by updating the session recv window from here
        // because there is a race between the sender and the
        // receiver: the sender may receive a window update and
        // send more data, while this method has not yet been
        // invoked; when the data is received the session recv
        // window may become negative and the connection will
        // be closed (per specification).

        if (frame.getStreamId() == 0) {
            int sessionWindow = session.updateRecvWindow(0);
            // Atomics.updateMax(maxSessionRecvWindow, sessionWindow);
            if(sessionWindow > maxSessionRecvWindow)
                maxSessionRecvWindow = sessionWindow;
        }
    }

    override
    string toString() {
        return format("%s@%x[ratio=%.2f,sessionLevel=%s,sessionStallTime=%dms,streamsStallTime=%dms]",
                typeof(this).stringof, toHash(), bufferRatio, sessionLevel, getSessionStallTime(),
                getStreamsStallTime());
    }
}
