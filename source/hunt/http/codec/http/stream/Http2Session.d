module hunt.http.codec.http.stream.Http2Session;

import hunt.http.codec.http.stream.CloseState;
import hunt.http.codec.http.stream.FlowControlStrategy;
import hunt.http.codec.http.stream.Http2Flusher;
import hunt.http.codec.http.stream.Http2Stream;
import hunt.http.codec.http.stream.Session;
import hunt.http.codec.http.stream.SessionSPI;
import hunt.http.codec.http.stream.Stream;
import hunt.http.codec.http.stream.StreamSPI;

import hunt.http.codec.http.decode.Parser;
import hunt.http.codec.http.encode.Generator;
import hunt.http.codec.http.frame;

import hunt.container;

import hunt.datetime;
import hunt.util.exception;
import hunt.util.functional;

import hunt.util.concurrent.atomic;
import hunt.util.concurrent.CountingCallback;
import hunt.util.concurrent.Promise;
import hunt.util.concurrent.Scheduler;

import hunt.net.Session;

import hunt.logging;

// import core.exception;

import std.algorithm;
import std.conv;
import std.datetime;
// import std.exception;
import std.format;
import std.range;
import std.typecons;

alias TcpSession = hunt.net.Session.Session;
alias StreamSession = hunt.http.codec.http.stream.Session.Session;


/**
*/
abstract class Http2Session : SessionSPI, Parser.Listener {

    // = new ConcurrentHashMap<>();
    // private AtomicInteger streamIds = new AtomicInteger();
    // private AtomicInteger lastStreamId = new AtomicInteger();
    // private AtomicInteger localStreamCount = new AtomicInteger();
    // private AtomicBiInteger remoteStreamCount = new AtomicBiInteger();
    // private AtomicInteger sendWindow = new AtomicInteger();
    // private AtomicInteger recvWindow = new AtomicInteger();
    // private AtomicReference<CloseState> closed = new AtomicReference<>(CloseState.NOT_CLOSED);
    // private AtomicLong bytesWritten = new AtomicLong();

    private StreamSPI[int] streams;
    private int streamIds ;
    private int lastStreamId ;
    private int localStreamCount ;
    private long remoteStreamCount ;
    private int sendWindow ;
    private int recvWindow ;
    private CloseState closed = CloseState.NOT_CLOSED;
    private long bytesWritten;

    private Scheduler scheduler;
    private TcpSession endPoint;
    private Generator generator;
    private StreamSession.Listener listener;
    private FlowControlStrategy flowControl;
    private Http2Flusher flusher;
    private int maxLocalStreams;
    private int maxRemoteStreams;
    private long streamIdleTimeout;
    private int initialSessionRecvWindow;
    private bool pushEnabled;
    private long idleTime;

    alias convertToMillisecond = convert!(TimeUnits.HectoNanosecond, TimeUnits.Millisecond);

    this(Scheduler scheduler, TcpSession endPoint, Generator generator,
                        StreamSession.Listener listener, FlowControlStrategy flowControl,
                        int initialStreamId, int streamIdleTimeout) {
        this.scheduler = scheduler;
        this.endPoint = endPoint;
        this.generator = generator;
        this.listener = listener;
        this.flowControl = flowControl;
        this.flusher = new Http2Flusher(this);
        this.maxLocalStreams = -1;
        this.maxRemoteStreams = -1;
        this.streamIds = (initialStreamId);
        this.streamIdleTimeout = streamIdleTimeout > 0 ? streamIdleTimeout : endPoint.getMaxIdleTimeout();
        this.sendWindow = (FlowControlStrategy.DEFAULT_WINDOW_SIZE);
        this.recvWindow = (FlowControlStrategy.DEFAULT_WINDOW_SIZE);
        this.pushEnabled = true; // SPEC: by default, push is enabled.
        this.idleTime = convertToMillisecond(Clock.currStdTime); //Millisecond100Clock.currentTimeMillis();
    }

    FlowControlStrategy getFlowControlStrategy() {
        return flowControl;
    }

    int getMaxLocalStreams() {
        return maxLocalStreams;
    }

    void setMaxLocalStreams(int maxLocalStreams) {
        this.maxLocalStreams = maxLocalStreams;
    }

    int getMaxRemoteStreams() {
        return maxRemoteStreams;
    }

    void setMaxRemoteStreams(int maxRemoteStreams) {
        this.maxRemoteStreams = maxRemoteStreams;
    }

    long getStreamIdleTimeout() {
        return streamIdleTimeout;
    }

    void setStreamIdleTimeout(long streamIdleTimeout) {
        this.streamIdleTimeout = streamIdleTimeout;
    }

    int getInitialSessionRecvWindow() {
        return initialSessionRecvWindow;
    }

    void setInitialSessionRecvWindow(int initialSessionRecvWindow) {
        this.initialSessionRecvWindow = initialSessionRecvWindow;
    }

    TcpSession getEndPoint() {
        return endPoint;
    }

    Generator getGenerator() {
        return generator;
    }

    override
    long getBytesWritten() {
        return bytesWritten;
    }

    override
    void onData(DataFrame frame) {
        version(HuntDebugMode) {
            tracef("Received %s", frame.toString());
        }
        int streamId = frame.getStreamId();
        StreamSPI stream = cast(StreamSPI) getStream(streamId);

        // SPEC: the session window must be updated even if the stream is null.
        // The flow control length includes the padding bytes.
        int flowControlLength = frame.remaining() + frame.padding();
        flowControl.onDataReceived(this, stream, flowControlLength);

        class DataCallback : NoopCallback
        {
            override
            void succeeded() {
                complete();
            }

            override
            void failed(Exception x) {
                // Consume also in case of failures, to free the
                // session flow control window for other streams.
                complete();
            }

            private void complete() {
                // notIdle();
                // stream.notIdle();
                flowControl.onDataConsumed(this.outer, stream, flowControlLength);
            }
        }

        if (stream !is null) {
            if (getRecvWindow() < 0) {
                close(cast(int)ErrorCode.FLOW_CONTROL_ERROR, "session_window_exceeded", Callback.NOOP);
            } else {
                stream.process(frame, new DataCallback() );
            }
        } else {
            version(HuntDebugMode) {
                tracef("Ignoring %s, stream #%s not found", frame.toString(), streamId);
            }
            // We must enlarge the session flow control window,
            // otherwise other requests will be stalled.
            flowControl.onDataConsumed(this, null, flowControlLength);
        }
    }

    override
    abstract void onHeaders(HeadersFrame frame);

    override
    void onPriority(PriorityFrame frame) {
        version(HuntDebugMode) {
            tracef("Received %s", frame.toString());
        }
    }

    override
    void onReset(ResetFrame frame) {
        version(HuntDebugMode) {
            tracef("Received %s", frame.toString());
        }
        StreamSPI stream = cast(StreamSPI)getStream(frame.getStreamId());
        if (stream !is null)
            stream.process(frame, new ResetCallback());
        else
            notifyReset(this, frame);
    }

    override
    void onSettings(SettingsFrame frame) {
        // SPEC: SETTINGS frame MUST be replied.
        onSettings(frame, true);
    }

    void onSettings(SettingsFrame frame, bool reply) {
        version(HuntDebugMode) {
            tracef("Received %s", frame.toString());
        }
        if (frame.isReply())
            return;

        // Iterate over all settings
        //for (Map.Entry!(int, int) entry : frame.getSettings().entrySet()) 
        foreach(int key, int value; frame.getSettings())
        {
            // int key = entry.getKey();
            // int value = entry.getValue();
            switch (key) {
                case SettingsFrame.HEADER_TABLE_SIZE: {
                    version(HuntDebugMode) {
                        tracef("Update HPACK header table size to %s for %s", value, this.toString());
                    }
                    generator.setHeaderTableSize(value);
                    break;
                }
                case SettingsFrame.ENABLE_PUSH: {
                    // SPEC: check the value is sane.
                    if (value != 0 && value != 1) {
                        onConnectionFailure(cast(int)ErrorCode.PROTOCOL_ERROR, "invalid_settings_enable_push");
                        return;
                    }
                    pushEnabled = value == 1;
                    version(HuntDebugMode) {
                        tracef("%s push for %s", pushEnabled ? "Enable" : "Disable", this.toString());
                    }
                    break;
                }
                case SettingsFrame.MAX_CONCURRENT_STREAMS: {
                    maxLocalStreams = value;
                    version(HuntDebugMode) {
                        tracef("Update max local concurrent streams to %s for %s", maxLocalStreams, this.toString());
                    }
                    break;
                }
                case SettingsFrame.INITIAL_WINDOW_SIZE: {
                    version(HuntDebugMode) {
                        tracef("Update initial window size to %s for %s", value, this.toString());
                    }
                    flowControl.updateInitialStreamWindow(this, value, false);
                    break;
                }
                case SettingsFrame.MAX_FRAME_SIZE: {
                    version(HuntDebugMode) {
                        tracef("Update max frame size to %s for %s", value, this.toString());
                    }
                    // SPEC: check the max frame size is sane.
                    if (value < Frame.DEFAULT_MAX_LENGTH || value > Frame.MAX_MAX_LENGTH) {
                        onConnectionFailure(cast(int)ErrorCode.PROTOCOL_ERROR, "invalid_settings_max_frame_size");
                        return;
                    }
                    generator.setMaxFrameSize(value);
                    break;
                }
                case SettingsFrame.MAX_HEADER_LIST_SIZE: {
                    version(HuntDebugMode) {
                        tracef("Update max header list size to %s for %s", value, this.toString());
                    }
                    generator.setMaxHeaderListSize(value);
                    break;
                }
                default: {
                    version(HuntDebugMode) {
                        tracef("Unknown setting %s:%s for %s", key, value, this.toString());
                    }
                    break;
                }
            }
        }
        notifySettings(this, frame);

        if (reply) {
            SettingsFrame replyFrame = new SettingsFrame(Collections.emptyMap!(int, int)(), true);
            settings(replyFrame, Callback.NOOP);
        }
    }

    override
    void onPing(PingFrame frame) {
        version(HuntDebugMode) {
            tracef("Received %s", frame.toString());
        }
        if (frame.isReply()) {
            info("The session %s received ping reply", endPoint.getSessionId());
            notifyPing(this, frame);
        } else {
            PingFrame reply = new PingFrame(frame.getPayload(), true);
            control(null, Callback.NOOP, reply);
        }
    }

    /**
     * This method is called when receiving a GO_AWAY from the other peer.
     * We check the close state to act appropriately:
     * <ul>
     * <li>NOT_CLOSED: we move to REMOTELY_CLOSED and queue a disconnect, so
     * that the content of the queue is written, and then the connection
     * closed. We notify the application after being terminated.
     * See <code>Http2Session.ControlEntry#succeeded()</code></li>
     * <li>In all other cases, we do nothing since other methods are already
     * performing their actions.</li>
     * </ul>
     *
     * @param frame the GO_AWAY frame that has been received.
     * @see #close(int, string, Callback)
     * @see #onShutdown()
     * @see #onIdleTimeout()
     */
    override
    void onGoAway(GoAwayFrame frame) {
        version(HuntDebugMode) {
            tracef("Received %s", frame.toString());
        }
        while (true) {
            CloseState current = closed;
            switch (current) {
                case CloseState.NOT_CLOSED: {
                    if (closed == current) {
                        closed = CloseState.REMOTELY_CLOSED;
                        // We received a GO_AWAY, so try to write
                        // what's in the queue and then disconnect.
                        notifyClose(this, frame, new DisconnectCallback());
                        return;
                    }
                    break;
                }
                default: {
                    version(HuntDebugMode) {
                        tracef("Ignored %s, already closed", frame.toString());
                    }
                    return;
                }
            }
        }
    }

    override
    void onWindowUpdate(WindowUpdateFrame frame) {
        version(HuntDebugMode) {
            tracef("Received %s", frame.toString());
        }
        int streamId = frame.getStreamId();
        if (streamId > 0) {
            StreamSPI stream = cast(StreamSPI)getStream(streamId);
            if (stream !is null) {
                stream.process(frame, Callback.NOOP);
                onWindowUpdate(stream, frame);
            }
        } else {
            onWindowUpdate(null, frame);
        }
    }

    override
    void onConnectionFailure(int error, string reason) {
        notifyFailure(this, new IOException(format("%d/%s", error, reason)), new CloseCallback(error, reason));
    }

    override
    void newStream(HeadersFrame frame, Promise!Stream promise, Stream.Listener listener) {
        // Synchronization is necessary to atomically create
        // the stream id and enqueue the frame to be sent.
        bool queued;
        synchronized (this) {
            int streamId = frame.getStreamId();
            if (streamId <= 0) {
                streamId = streamIds; streamIds += 2; // streamIds.getAndAdd(2);
                PriorityFrame priority = frame.getPriority();
                priority = priority is null ? null : new PriorityFrame(streamId, priority.getParentStreamId(),
                        priority.getWeight(), priority.isExclusive());
                frame = new HeadersFrame(streamId, frame.getMetaData(), priority, frame.isEndStream());
            }
            StreamSPI stream = createLocalStream(streamId, promise);
            if (stream is null)
                return;
            stream.setListener(listener);

            ControlEntry entry = new ControlEntry(frame, stream, new PromiseCallback!Stream(promise, stream));
            queued = flusher.append(entry);
        }
        // Iterate outside the synchronized block.
        if (queued)
            flusher.iterate();
    }

    override
    int priority(PriorityFrame frame, Callback callback) {
        int streamId = frame.getStreamId();
        StreamSPI stream = streams[streamId];
        if (stream is null) {
            streamId = streamIds; streamIds += 2; //.getAndAdd(2);
            frame = new PriorityFrame(streamId, frame.getParentStreamId(),
                    frame.getWeight(), frame.isExclusive());
        }
        control(stream, callback, frame);
        return streamId;
    }

    override
    void push(StreamSPI stream, Promise!Stream promise, PushPromiseFrame frame, Stream.Listener listener) {
        // Synchronization is necessary to atomically create
        // the stream id and enqueue the frame to be sent.
        bool queued;
        synchronized (this) {
            int streamId = streamIds; streamIds += 2; //.getAndAdd(2);
            frame = new PushPromiseFrame(frame.getStreamId(), streamId, frame.getMetaData());

            StreamSPI pushStream = createLocalStream(streamId, promise);
            if (pushStream is null)
                return;
            pushStream.setListener(listener);

            ControlEntry entry = new ControlEntry(frame, pushStream, new PromiseCallback!Stream(promise, pushStream));
            queued = flusher.append(entry);
        }
        // Iterate outside the synchronized block.
        if (queued)
            flusher.iterate();
    }

    override
    void settings(SettingsFrame frame, Callback callback) {
        control(null, callback, frame);
    }

    override
    void ping(PingFrame frame, Callback callback) {
        if (frame.isReply())
            callback.failed(new IllegalArgumentException(""));
        else
            control(null, callback, frame);
    }

    protected void reset(ResetFrame frame, Callback callback) {
        control(cast(StreamSPI)getStream(frame.getStreamId()), callback, frame);
    }

    /**
     * Invoked internally and by applications to send a GO_AWAY frame to the
     * other peer. We check the close state to act appropriately:
     * <ul>
     * <li>NOT_CLOSED: we move to LOCALLY_CLOSED and queue a GO_AWAY. When the
     * GO_AWAY has been written, it will only cause the output to be shut
     * down (not the connection closed), so that the application can still
     * read frames arriving from the other peer.
     * Ideally the other peer will notice the GO_AWAY and close the connection.
     * When that happen, we close the connection from {@link #onShutdown()}.
     * Otherwise, the idle timeout mechanism will close the connection, see
     * {@link #onIdleTimeout()}.</li>
     * <li>In all other cases, we do nothing since other methods are already
     * performing their actions.</li>
     * </ul>
     *
     * @param error    the error code
     * @param reason   the reason
     * @param callback the callback to invoke when the operation is complete
     * @see #onGoAway(GoAwayFrame)
     * @see #onShutdown()
     * @see #onIdleTimeout()
     */
    override
    bool close(int error, string reason, Callback callback) {
        while (true) {
            CloseState current = closed;
            switch (current) {
                case CloseState.NOT_CLOSED: {
                    if (closed == current) {
                        closed =  CloseState.LOCALLY_CLOSED;
                        GoAwayFrame frame = newGoAwayFrame(error, reason);
                        control(null, callback, frame);
                        return true;
                    }
                    break;
                }
                default: {
                    version(HuntDebugMode)
                        tracef("Ignoring close %s/%s, already closed", error, reason);
                    callback.succeeded();
                    return false;
                }
            }
        }
    }

    private GoAwayFrame newGoAwayFrame(int error, string reason) {
        byte[] payload = null;
        if (!reason.empty) {
            // Trim the reason to avoid attack vectors.
            int len = min(reason.length, 32);
            payload = cast(byte[])reason[0..len].dup;
        }
        return new GoAwayFrame(lastStreamId, error, payload);
    }

    override
    bool isClosed() {
        return closed != CloseState.NOT_CLOSED;
    }

    private void control(StreamSPI stream, Callback callback, Frame frame) {
        frames(stream, callback, frame, Frame.EMPTY_ARRAY);
    }

    override
    void frames(StreamSPI stream, Callback callback, Frame frame, Frame[] frames... ) {
        // We want to generate as late as possible to allow re-prioritization;
        // generation will happen while processing the entries.

        // The callback needs to be notified only when the last frame completes.

        int length = cast(int)frames.length;
        if (length == 0) {
            onFrame(new ControlEntry(frame, stream, callback), true);
        } else {
            callback = new CountingCallback(callback, 1 + length);
            onFrame(new ControlEntry(frame, stream, callback), false);
            for (int i = 1; i <= length; ++i)
                onFrame(new ControlEntry(frames[i - 1], stream, callback), i == length);
        }
    }

    override
    void data(StreamSPI stream, Callback callback, DataFrame frame) {
        // We want to generate as late as possible to allow re-prioritization.
        onFrame(new DataEntry(frame, stream, callback), true);
    }

    private void onFrame(Http2Flusher.Entry entry, bool flush) {
        version(HuntDebugMode) {
            tracef("%s %s", flush ? "Sending" : "Queueing", entry.frame.toString());
        }
        // Ping frames are prepended to process them as soon as possible.
        bool queued = entry.frame.getType() == FrameType.PING ? flusher.prepend(entry) : flusher.append(entry);
        if (queued && flush) {
            if (entry.stream !is null) {
                // entry.stream.notIdle();
            }
            flusher.iterate();
        }
    }

    protected StreamSPI createLocalStream(int streamId, Promise!Stream promise) {
        while (true) {
            int localCount = localStreamCount;
            int maxCount = getMaxLocalStreams();
            if (maxCount >= 0 && localCount >= maxCount) {
                promise.failed(new IllegalStateException("Max local stream count " ~ maxCount.to!string() ~ " exceeded"));
                return null;
            }
            if (localStreamCount == localCount)
            {
                localStreamCount =  localCount + 1;
                break;
            }
        }

        StreamSPI stream = newStream(streamId, true);
        auto itemPtr = streamId in streams;
        if (itemPtr is null) {
            streams[streamId] = stream;
            // stream.setIdleTimeout(getStreamIdleTimeout());
            flowControl.onStreamCreated(stream);
            version(HuntDebugMode) {
                tracef("Created local %s", stream.toString());
            }
            return stream;
        } else {
            promise.failed(new IllegalStateException("Duplicate stream " ~ streamId.to!string()));
            return null;
        }
    }

    protected StreamSPI createRemoteStream(int streamId) {
        // SPEC: exceeding max concurrent streams is treated as stream error.
        while (true) {
            long encoded = remoteStreamCount;
            int remoteCount = AtomicBiInteger.getHi(encoded);
            int remoteClosing = AtomicBiInteger.getLo(encoded);
            int maxCount = getMaxRemoteStreams();
            if (maxCount >= 0 && remoteCount - remoteClosing >= maxCount) {
                reset(new ResetFrame(streamId, cast(int)ErrorCode.REFUSED_STREAM_ERROR), Callback.NOOP);
                return null;
            }
            // if (remoteStreamCount.compareAndSet(encoded, remoteCount + 1, remoteClosing))
            if(remoteStreamCount == encoded)
            {
                remoteStreamCount = AtomicBiInteger.encode(remoteCount + 1, remoteClosing);
                break;
            }
        }

        StreamSPI stream = newStream(streamId, false);

        // SPEC: duplicate stream is treated as connection error.
        //streams.putIfAbsent(streamId, stream)
        auto itemPtr = streamId in streams;
        if ( itemPtr is null) {
            streams[streamId] = stream;
            updateLastStreamId(streamId);
            // stream.setIdleTimeout(getStreamIdleTimeout());
            flowControl.onStreamCreated(stream);
            version(HuntDebugMode) {
                tracef("Created remote %s", stream.toString());
            }
            return stream;
        } else {
            close(cast(int)ErrorCode.PROTOCOL_ERROR, "duplicate_stream", Callback.NOOP);
            return null;
        }
    }

    void updateStreamCount(bool local, int deltaStreams, int deltaClosing) {
        if (local)
            localStreamCount += (deltaStreams);
        else
        {
            remoteStreamCount = AtomicBiInteger.encode(remoteStreamCount, deltaStreams, deltaClosing);
            // remoteStreamCount.add(deltaStreams, deltaClosing);
        }
    }

    protected StreamSPI newStream(int streamId, bool local) {
        return new Http2Stream(scheduler, this, streamId, local);
    }

    override
    void removeStream(StreamSPI stream) {
        bool removed = streams.remove(stream.getId());
        if (removed) {
            onStreamClosed(stream);
            flowControl.onStreamDestroyed(stream);
            version(HuntDebugMode) {
                tracef("Removed %s %s", stream.isLocal() ? "local" : "remote", stream);
            }
        }
    }

    override
    Stream[] getStreams() {
        return cast(Stream[])(streams.values());
    }

    int getStreamCount() {
        return cast(int)streams.length;
    }

    override
    StreamSPI getStream(int streamId) {
        return streams[streamId];
    }

    int getSendWindow() {
        return sendWindow;
    }

    int getRecvWindow() {
        return recvWindow;
    }

    override
    int updateSendWindow(int delta) {
        int old = sendWindow;
        sendWindow += delta;
        return old; 
    }

    override
    int updateRecvWindow(int delta) {
        int old = recvWindow;
        recvWindow += delta;
        return old; 
    }

    override
    void onWindowUpdate(StreamSPI stream, WindowUpdateFrame frame) {
        // WindowUpdateFrames arrive concurrently with writes.
        // Increasing (or reducing) the window size concurrently
        // with writes requires coordination with the flusher, that
        // decides how many frames to write depending on the available
        // window sizes. If the window sizes vary concurrently, the
        // flusher may take non-optimal or wrong decisions.
        // Here, we "queue" window updates to the flusher, so it will
        // be the only component responsible for window updates, for
        // both increments and reductions.
        flusher.window(stream, frame);
    }

    override
    bool isPushEnabled() {
        return pushEnabled;
    }

    /**
     * A typical close by a remote peer involves a GO_AWAY frame followed by TCP FIN.
     * This method is invoked when the TCP FIN is received, or when an exception is
     * thrown while reading, and we check the close state to act appropriately:
     * <ul>
     * <li>NOT_CLOSED: means that the remote peer did not send a GO_AWAY (abrupt close)
     * or there was an exception while reading, and therefore we terminate.</li>
     * <li>LOCALLY_CLOSED: we have sent the GO_AWAY to the remote peer, which received
     * it and closed the connection; we queue a disconnect to close the connection
     * on the local side.
     * The GO_AWAY just shutdown the output, so we need this step to make sure the
     * connection is closed. See {@link #close(int, string, Callback)}.</li>
     * <li>REMOTELY_CLOSED: we received the GO_AWAY, and the TCP FIN afterwards, so we
     * do nothing since the handling of the GO_AWAY will take care of closing the
     * connection. See {@link #onGoAway(GoAwayFrame)}.</li>
     * </ul>
     *
     * @see #onGoAway(GoAwayFrame)
     * @see #close(int, string, Callback)
     * @see #onIdleTimeout()
     */
    override
    void onShutdown() {
        version(HuntDebugMode) {
            tracef("Shutting down %s", this.toString());
        }
        switch (closed) {
            case CloseState.NOT_CLOSED: {
                // The other peer did not send a GO_AWAY, no need to be gentle.
                version(HuntDebugMode) {
                    tracef("Abrupt close for %s", this.toString());
                }
                abort(new ClosedChannelException(""));
                break;
            }
            case CloseState.LOCALLY_CLOSED: {
                // We have closed locally, and only shutdown
                // the output; now queue a disconnect.
                control(null, Callback.NOOP, new DisconnectFrame());
                break;
            }
            case CloseState.REMOTELY_CLOSED: {
                // Nothing to do, the GO_AWAY frame we
                // received will close the connection.
                break;
            }
            default: {
                break;
            }
        }
    }

    /**
     * This method is invoked when the idle timeout triggers. We check the close state
     * to act appropriately:
     * <ul>
     * <li>NOT_CLOSED: it's a real idle timeout, we just initiate a close, see
     * {@link #close(int, string, Callback)}.</li>
     * <li>LOCALLY_CLOSED: we have sent a GO_AWAY and only shutdown the output, but the
     * other peer did not close the connection so we never received the TCP FIN, and
     * therefore we terminate.</li>
     * <li>REMOTELY_CLOSED: the other peer sent us a GO_AWAY, we should have queued a
     * disconnect, but for some reason it was not processed (for example, queue was
     * stuck because of TCP congestion), therefore we terminate.
     * See {@link #onGoAway(GoAwayFrame)}.</li>
     * </ul>
     *
     * @return true if the session should be closed, false otherwise
     * @see #onGoAway(GoAwayFrame)
     * @see #close(int, string, Callback)
     * @see #onShutdown()
     */
    override
    bool onIdleTimeout() {
        switch (closed) {
            case CloseState.NOT_CLOSED: {
                long elapsed = convertToMillisecond(Clock.currStdTime) - idleTime;
                version(HuntDebugMode) {
                    tracef("HTTP2 session on idle timeout. The elapsed time is %s - %s", elapsed, endPoint.getMaxIdleTimeout());
                }
                return elapsed >= endPoint.getMaxIdleTimeout() && notifyIdleTimeout(this);
            }
            case CloseState.LOCALLY_CLOSED:
            case CloseState.REMOTELY_CLOSED: {
                abort(new TimeoutException("Idle timeout " ~ endPoint.getMaxIdleTimeout().to!string() ~ " ms"));
                return false;
            }
            default: {
                return false;
            }
        }
    }

    private void notIdle() {
        idleTime = convertToMillisecond(Clock.currStdTime);
    }

    override
    void onFrame(Frame frame) {
        onConnectionFailure(cast(int)ErrorCode.PROTOCOL_ERROR, "upgrade");
    }

    protected void onStreamOpened(StreamSPI stream) {
    }

    protected void onStreamClosed(StreamSPI stream) {
    }

    void disconnect() {
        version(HuntDebugMode) {
            tracef("Disconnecting %s", this.toString());
        }
        endPoint.close();
    }

    private void terminate(Exception cause) {
        while (true) {
            CloseState current = closed;
            switch (current) {
                case CloseState.NOT_CLOSED:
                case CloseState.LOCALLY_CLOSED:
                case CloseState.REMOTELY_CLOSED: {
                    if (closed == current) {
                        closed = CloseState.CLOSED;
                        flusher.terminate(cause);
                        foreach (StreamSPI stream ; streams.byValue())
                            stream.close();
                        streams.clear();
                        disconnect();
                        return;
                    }
                    break;
                }
                default: {
                    return;
                }
            }
        }
    }

    void abort(Exception failure) {
        notifyFailure(this, failure, new TerminateCallback(failure));
    }

    bool isDisconnected() {
        return !endPoint.isOpen();
    }

    private void updateLastStreamId(int streamId) {
        // Atomics.updateMax(lastStreamId, streamId);
        if(streamId>lastStreamId) lastStreamId = streamId;
    }

    protected Stream.Listener notifyNewStream(Stream stream, HeadersFrame frame) {
        try {
            return listener.onNewStream(stream, frame);
        } catch (Exception x) {
            info("Failure while notifying listener " ~ listener.toString(), x);
            return null;
        }
    }

    protected void notifySettings(StreamSession session, SettingsFrame frame) {
        try {
            listener.onSettings(session, frame);
        } catch (Exception x) {
            info("Failure while notifying listener " ~ listener.toString(), x);
        }
    }

    protected void notifyPing(StreamSession session, PingFrame frame) {
        try {
            listener.onPing(session, frame);
        } catch (Exception x) {
            info("Failure while notifying listener " ~ listener.toString(), x);
        }
    }

    protected void notifyReset(StreamSession session, ResetFrame frame) {
        try {
            listener.onReset(session, frame);
        } catch (Exception x) {
            info("Failure while notifying listener " ~ listener.toString(), x);
        }
    }

    protected void notifyClose(StreamSession session, GoAwayFrame frame, Callback callback) {
        try {
            listener.onClose(session, frame, callback);
        } catch (Exception x) {
            info("Failure while notifying listener " ~ listener.toString(), x);
        }
    }

    protected bool notifyIdleTimeout(StreamSession session) {
        try {
            return listener.onIdleTimeout(session);
        } catch (Exception x) {
            info("Failure while notifying listener " ~ listener.toString(), x);
            return true;
        }
    }

    protected void notifyFailure(StreamSession session, Exception failure, Callback callback) {
        try {
            listener.onFailure(session, failure, callback);
        } catch (Exception x) {
            info("Failure while notifying listener " ~ listener.toString(), x);
        }
    }

    protected void notifyHeaders(StreamSPI stream, HeadersFrame frame) {
        // Optional.ofNullable(stream.getListener()).ifPresent(listener -> {
        //     try {
        //         listener.onHeaders(stream, frame);
        //     } catch (Exception x) {
        //         info("Failure while notifying listener " ~ listener.toString(), x);
        //     }
        // });
        auto listener = stream.getListener();
        if(listener !is null)
        {
            try {
                listener.onHeaders(stream, frame);
            } catch (Exception x) {
                info("Failure while notifying listener " ~ listener.toString(), x);
            }            
        }
    }

    override
    string toString() {
        return format("%s@%s{l:%s <-> r:%s,sendWindow=%s,recvWindow=%s,streams=%d,%s}",
                typeof(this).stringof,
                toHash(),
                getEndPoint().getLocalAddress(),
                getEndPoint().getRemoteAddress(),
                sendWindow,
                recvWindow,
                streams.length,
                closed);
    }

    private class ControlEntry : Http2Flusher.Entry {
        private int bytes;

        private this(Frame frame, StreamSPI stream, Callback callback) {
            super(frame, stream, callback);
        }

        override
        protected bool generate(Queue!ByteBuffer buffers) {
            List!(ByteBuffer) controlFrame = generator.control(frame);
            bytes = cast(int) BufferUtils.remaining(controlFrame);
            buffers.addAll(controlFrame);
            version(HuntDebugMode) {
                tracef("Generated %s", frame.toString());
            }
            beforeSend();
            return true;
        }

        /**
         * <p>Performs actions just before writing the frame to the network.</p>
         * <p>Some frame, when sent over the network, causes the receiver
         * to react and send back frames that may be processed by the original
         * sender *before* {@link #succeeded()} is called.
         * <p>If the action to perform updates some state, this update may
         * not be seen by the received frames and cause errors.</p>
         * <p>For example, suppose the action updates the stream window to a
         * larger value; the sender sends the frame; the receiver is now entitled
         * to send back larger data; when the data is received by the original
         * sender, the action may have not been performed yet, causing the larger
         * data to be rejected, when it should have been accepted.</p>
         */
        private void beforeSend() {
            switch (frame.getType()) {
                case FrameType.HEADERS: {
                    HeadersFrame headersFrame = cast(HeadersFrame) frame;
                    stream.updateClose(headersFrame.isEndStream(), CloseStateEvent.BEFORE_SEND);
                    break;
                }
                case FrameType.SETTINGS: {
                    SettingsFrame settingsFrame = cast(SettingsFrame) frame;
                    Map!(int, int) settings = settingsFrame.getSettings();
                    if (settings.containsKey(SettingsFrame.INITIAL_WINDOW_SIZE))
                    {
                        int initialWindow = settings.get(SettingsFrame.INITIAL_WINDOW_SIZE);
                        flowControl.updateInitialStreamWindow(this.outer, initialWindow, true);
                    }
                    break;
                }
                default: {
                    break;
                }
            }
        }

        override
        void succeeded() {
            bytesWritten += (bytes);
            switch (frame.getType()) {
                case FrameType.HEADERS: {
                    onStreamOpened(stream);
                    HeadersFrame headersFrame = cast(HeadersFrame) frame;
                    if (stream.updateClose(headersFrame.isEndStream(), CloseStateEvent.AFTER_SEND))
                        removeStream(stream);
                    break;
                }
                case FrameType.RST_STREAM: {
                    if (stream !is null) {
                        stream.close();
                        removeStream(stream);
                    }
                    break;
                }
                case FrameType.PUSH_PROMISE: {
                    // Pushed streams are implicitly remotely closed.
                    // They are closed when sending an end-stream DATA frame.
                    stream.updateClose(true, CloseStateEvent.RECEIVED);
                    break;
                }
                case FrameType.GO_AWAY: {
                    // We just sent a GO_AWAY, only shutdown the
                    // output without closing yet, to allow reads.
                    getEndPoint().shutdownOutput();
                    break;
                }
                case FrameType.WINDOW_UPDATE: {
                    flowControl.windowUpdate(this.outer, stream, cast(WindowUpdateFrame) frame);
                    break;
                }
                case FrameType.DISCONNECT: {
                    terminate(new ClosedChannelException(""));
                    break;
                }
                default: {
                    break;
                }
            }
            super.succeeded();
        }

        override
        void failed(Exception x) {
            if (frame.getType() == FrameType.DISCONNECT) {
                terminate(new ClosedChannelException(""));
            }
            super.failed(x);
        }
    }

    private class DataEntry :Http2Flusher.Entry {
        private int bytes;
        private int _dataRemaining;
        private int dataWritten;

        private this(DataFrame frame, StreamSPI stream, Callback callback) {
            super(frame, stream, callback);
            // We don't do any padding, so the flow control length is
            // always the data remaining. This simplifies the handling
            // of data frames that cannot be completely written due to
            // the flow control window exhausting, since in that case
            // we would have to count the padding only once.
            _dataRemaining = frame.remaining();
        }

        override
        int dataRemaining() {
            return _dataRemaining;
        }

        override
        protected bool generate(Queue!ByteBuffer buffers) {
            int remaining = dataRemaining();

            int sessionSendWindow = getSendWindow();
            int streamSendWindow = stream.updateSendWindow(0);
            int window = min(streamSendWindow, sessionSendWindow);
            if (window <= 0 && remaining > 0)
                return false;

            int length = min(remaining, window);

            // Only one DATA frame is generated.
            DataFrame dataFrame = cast(DataFrame) frame;
            Tuple!(int, List!(ByteBuffer)) pair = generator.data(dataFrame, length);
            bytes = pair[0];
            buffers.addAll(pair[1]);
            int written = bytes - Frame.HEADER_LENGTH;
            version(HuntDebugMode) {
                tracef("Generated %s, length/window/data=%s/%s/%s", dataFrame, written, window, remaining);
            }
            this.dataWritten = written;
            this._dataRemaining -= written;

            flowControl.onDataSending(stream, written);
            stream.updateClose(dataFrame.isEndStream(), CloseStateEvent.BEFORE_SEND);

            return true;
        }

        override
        void succeeded() {
            bytesWritten += bytes;
            flowControl.onDataSent(stream, dataWritten);

            // Do we have more to send ?
            DataFrame dataFrame = cast(DataFrame) frame;
            if (_dataRemaining == 0) {
                // Only now we can update the close state
                // and eventually remove the stream.
                if (stream.updateClose(dataFrame.isEndStream(), CloseStateEvent.AFTER_SEND))
                    removeStream(stream);
                super.succeeded();
            }
        }
    }

    private static class PromiseCallback(C) : NoopCallback {
        private Promise!C promise;
        private C value;

        private this(Promise!C promise, C value) {
            this.promise = promise;
            this.value = value;
        }

        override
        void succeeded() {
            promise.succeeded(value);
        }

        override
        void failed(Exception x) {
            promise.failed(x);
        }
    }

    private class ResetCallback : NoopCallback {
        override
        void succeeded() {
            complete();
        }

        override
        void failed(Exception x) {
            complete();
        }

        private void complete() {
            flusher.iterate();
        }
    }

    private class CloseCallback : NoopCallback {
        private int error;
        private string reason;

        private this(int error, string reason) {
            this.error = error;
            this.reason = reason;
        }

        override
        void succeeded() {
            complete();
        }

        override
        void failed(Exception x) {
            complete();
        }

        private void complete() {
            close(error, reason, Callback.NOOP);
        }
    }

    private class DisconnectCallback : NoopCallback {
        override
        void succeeded() {
            complete();
        }

        override
        void failed(Exception x) {
            complete();
        }

        private void complete() {
            frames(null, Callback.NOOP, newGoAwayFrame(cast(int)ErrorCode.NO_ERROR, null), new DisconnectFrame());
        }
    }

    private class TerminateCallback : NoopCallback {
        private Exception failure;

        private this(Exception failure) {
            this.failure = failure;
        }

        override
        void succeeded() {
            complete();
        }

        override
        void failed(Exception x) {
            // failure.addSuppressed(x);
            Throwable.chainTogether(failure, x);
            complete();
        }

        private void complete() {
            terminate(failure);
        }
    }
}
