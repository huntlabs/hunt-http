module hunt.http.codec.http.stream.AbstractFlowControlStrategy;

import hunt.http.codec.http.stream.FlowControlStrategy;
import hunt.http.codec.http.stream.Stream;
import hunt.http.codec.http.stream.StreamSPI;
import hunt.http.codec.http.stream.SessionSPI;

import hunt.http.codec.http.frame.WindowUpdateFrame;

import hunt.logger;
import std.datetime;
import core.time;

import hunt.util.exception;
import hunt.datetime;
import hunt.container.Map;


abstract class AbstractFlowControlStrategy : FlowControlStrategy {
    
    // private AtomicLong sessionStall = new AtomicLong();
    // private AtomicLong sessionStallTime = new AtomicLong();
    // private Map!(StreamSPI, long) streamsStalls = new ConcurrentHashMap!(StreamSPI, long)();
    // private AtomicLong streamsStallTime = new AtomicLong();
    private long sessionStall;
    private long sessionStallTime;
    private long streamsStallTime;
    private long[StreamSPI] streamsStalls;

    private int initialStreamSendWindow;
    private int initialStreamRecvWindow;

    this(int initialStreamSendWindow) {
        this.initialStreamSendWindow = initialStreamSendWindow;
        this.initialStreamRecvWindow = DEFAULT_WINDOW_SIZE; 
    }

    int getInitialStreamSendWindow() {
        return initialStreamSendWindow;
    }

    int getInitialStreamRecvWindow() {
        return initialStreamRecvWindow;
    }

    override
    void onStreamCreated(StreamSPI stream) {
        stream.updateSendWindow(initialStreamSendWindow);
        stream.updateRecvWindow(initialStreamRecvWindow);
    }

    override
    void onStreamDestroyed(StreamSPI stream) {
        streamsStalls.remove(stream);
    }

	void onDataConsumed(SessionSPI session, StreamSPI stream, int length) { implementationMissing(); }

    override
    void updateInitialStreamWindow(SessionSPI session, int initialStreamWindow, bool local) {
        int previousInitialStreamWindow;
        if (local) {
            previousInitialStreamWindow = getInitialStreamRecvWindow();
            this.initialStreamRecvWindow = initialStreamWindow;
        } else {
            previousInitialStreamWindow = getInitialStreamSendWindow();
            this.initialStreamSendWindow = initialStreamWindow;
        }
        int delta = initialStreamWindow - previousInitialStreamWindow;

        // SPEC: updates of the initial window size only affect stream windows, not session's.
        foreach (Stream stream ; session.getStreams()) {
            if (local) {
                (cast(StreamSPI) stream).updateRecvWindow(delta);
                version(HuntDebugMode)
                    tracef("Updated initial stream recv window %s -> %s for %s", previousInitialStreamWindow, initialStreamWindow, stream);
            } else {
                session.onWindowUpdate(cast(StreamSPI) stream, new WindowUpdateFrame(stream.getId(), delta));
            }
        }
    }

    override
    void onWindowUpdate(SessionSPI session, StreamSPI stream, WindowUpdateFrame frame) {
        int delta = frame.getWindowDelta();
        if (frame.getStreamId() > 0) {
            // The stream may have been removed concurrently.
            if (stream !is null) {
                int oldSize = stream.updateSendWindow(delta);
                version(HuntDebugMode)
                    tracef("Updated stream send window %s -> %s for %s", oldSize, oldSize + delta, stream);
                if (oldSize <= 0)
                    onStreamUnstalled(stream);
            }
        } else {
            int oldSize = session.updateSendWindow(delta);
            version(HuntDebugMode)
                tracef("Updated session send window %s -> %s for %s", oldSize, oldSize + delta, session);
            if (oldSize <= 0)
                onSessionUnstalled(session);
        }
    }

    override
    void onDataReceived(SessionSPI session, StreamSPI stream, int length) {
        int oldSize = session.updateRecvWindow(-length);
        version(HuntDebugMode)
            tracef("Data received, %s bytes, updated session recv window %s -> %s for %s", length, oldSize, oldSize - length, session);

        if (stream !is null) {
            oldSize = stream.updateRecvWindow(-length);
            version(HuntDebugMode)
                tracef("Data received, %s bytes, updated stream recv window %s -> %s for %s", length, oldSize, oldSize - length, stream);
        }
    }

    override
    void windowUpdate(SessionSPI session, StreamSPI stream, WindowUpdateFrame frame) {
    }

    override
    void onDataSending(StreamSPI stream, int length) {
        if (length == 0)
            return;

        SessionSPI session = stream.getSession();
        int oldSessionWindow = session.updateSendWindow(-length);
        int newSessionWindow = oldSessionWindow - length;
        version(HuntDebugMode)
            tracef("Sending, session send window %s -> %s for %s", oldSessionWindow, newSessionWindow, session);
        if (newSessionWindow <= 0)
            onSessionStalled(session);

        int oldStreamWindow = stream.updateSendWindow(-length);
        int newStreamWindow = oldStreamWindow - length;
        version(HuntDebugMode)
            tracef("Sending, stream send window %s -> %s for %s", oldStreamWindow, newStreamWindow, stream);
        if (newStreamWindow <= 0)
            onStreamStalled(stream);
    }

    override
    void onDataSent(StreamSPI stream, int length) {
    }

    protected void onSessionStalled(SessionSPI session) {
        sessionStall = Clock.currStdTime;
        version(HuntDebugMode)
            tracef("Session stalled %s", session);
    }

    protected void onStreamStalled(StreamSPI stream) {
        streamsStalls[stream] = Clock.currStdTime;
        version(HuntDebugMode)
            tracef("Stream stalled %s", stream);
    }

    protected void onSessionUnstalled(SessionSPI session) {
        sessionStallTime += (Clock.currStdTime - sessionStall);
        sessionStall = 0;
        version(HuntDebugMode)
            tracef("Session unstalled %s", session);
    }

    protected void onStreamUnstalled(StreamSPI stream) {
        auto itemPtr = stream in streamsStalls;
        
        if (itemPtr !is null)
        {
            long time = *itemPtr;
            streamsStalls.remove(stream);
            streamsStallTime += (Clock.currStdTime - time);

        }
        version(HuntDebugMode)
            tracef("Stream unstalled %s", stream);
    }

    long getSessionStallTime() {
        long pastStallTime = sessionStallTime;
        long currentStallTime = sessionStall;
        if (currentStallTime != 0)
            currentStallTime = Clock.currStdTime - currentStallTime;
        return convert!(TimeUnits.HectoNanosecond, TimeUnits.Millisecond)(pastStallTime + currentStallTime);
    }

    long getStreamsStallTime() {
        long pastStallTime = streamsStallTime;
        long now = Clock.currStdTime;
        // long currentStallTime = streamsStalls.values().stream().reduce(0L, (result, time) => now - time);
        long currentStallTime = 0L;
        foreach(long v; streamsStalls.byValue)
        {
            currentStallTime =  now - v;           
        }

        return convert!(TimeUnits.HectoNanosecond, TimeUnits.Millisecond)(pastStallTime + currentStallTime);
    }

    void reset() {
        sessionStallTime = (0);
        streamsStallTime = (0);
    }
}
