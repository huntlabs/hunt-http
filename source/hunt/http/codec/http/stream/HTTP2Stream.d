module hunt.http.codec.http.stream.HTTP2Stream;

import hunt.http.codec.http.stream.CloseState;
import hunt.http.codec.http.stream.HTTP2Session;
import hunt.http.codec.http.stream.SessionSPI;
import hunt.http.codec.http.stream.Stream;
import hunt.http.codec.http.stream.StreamSPI;

import hunt.http.codec.http.frame;
// import hunt.http.utils.concurrent.IdleTimeout;
import hunt.util.concurrent.Promise;
// import hunt.http.utils.concurrent.Scheduler;

import hunt.util.concurrent.Scheduler;
import hunt.util.functional;
import hunt.util.exception;

import hunt.logging;
import std.format;

alias Listener = hunt.http.codec.http.stream.Stream.Stream.Listener;

/**
*/
class HTTP2Stream : StreamSPI { // IdleTimeout, 

    // private AtomicReference<ConcurrentMap<string, Object>> attributes = new AtomicReference<>();
    // private AtomicReference<CloseState> closeState = new AtomicReference<>(CloseState.NOT_CLOSED);
    // private AtomicInteger sendWindow = new AtomicInteger();
    // private AtomicInteger recvWindow = new AtomicInteger();

    private Object[string] attributes;
    private CloseState closeState;
    private int sendWindow;
    private int recvWindow;

    private SessionSPI session;
    private int streamId;
    private bool local;
    private  Listener listener;
    private  bool localReset;
    private  bool remoteReset;

    this(Scheduler scheduler, SessionSPI session, int streamId, bool local) {
        // super(scheduler);
        closeState = CloseState.NOT_CLOSED; 
        this.session = session;
        this.streamId = streamId;
        this.local = local;
    }

    // override
    int getId() {
        return streamId;
    }

    // override
    bool isLocal() {
        return local;
    }

    // override
    SessionSPI getSession() {
        return session;
    }

    // override
    void headers(HeadersFrame frame, Callback callback) {
        session.frames(this, callback, frame, Frame.EMPTY_ARRAY);
    }

    // override
    void push(PushPromiseFrame frame, Promise!Stream promise, Listener listener) {
        session.push(this, promise, frame, listener);
    }

    // override
    void data(DataFrame frame, Callback callback) {
        session.data(this, callback, frame);
    }

    // override
    void reset(ResetFrame frame, Callback callback) {
        if (isReset())
            return;
        localReset = true;
        session.frames(this, callback, frame, Frame.EMPTY_ARRAY);
    }

    // override
    Object getAttribute(string key) {
        return attributes[key];
    }

    // override
    void setAttribute(string key, Object value) {
        attributes[key] = value;
    }

    // override
    Object removeAttribute(string key) {
        auto r = attributes[key];
        attributes.remove(key);
        return r;
    }

    // override
    bool isReset() {
        return localReset || remoteReset;
    }

    // override
    bool isClosed() {
        return closeState == CloseState.CLOSED;
    }

    // override
    bool isRemotelyClosed() {
        return closeState == CloseState.REMOTELY_CLOSED;
    }

    bool isLocallyClosed() {
        return closeState == CloseState.LOCALLY_CLOSED;
    }

    // override
    bool isOpen() {
        return !isClosed();
    }

    // override
    protected void onIdleExpired(TimeoutException timeout) {
        version(HuntDebugMode) {
            tracef("Idle timeout %sms expired on %s", 0, this.toString()); // getIdleTimeout()
        }

        // Notify the application.
        if (notifyIdleTimeout(this, timeout)) {
            // Tell the other peer that we timed out.
            reset(new ResetFrame(getId(), cast(int)ErrorCode.CANCEL_STREAM_ERROR), Callback.NOOP);
        }
    }

    // private ConcurrentMap<string, Object> attributes() {
    //     ConcurrentMap<string, Object> map = attributes;
    //     if (map == null) {
    //         map = new ConcurrentHashMap<>();
    //         if (!attributes.compareAndSet(null, map)) {
    //             map = attributes;
    //         }
    //     }
    //     return map;
    // }

    // override
    Listener getListener() {
        return listener;
    }

    // override
    void setListener(Listener listener) {
        this.listener = listener;
    }

    // override
    void process(Frame frame, Callback callback) {
        // notIdle();
        switch (frame.getType()) {
            case FrameType.HEADERS: {
                onHeaders(cast(HeadersFrame) frame, callback);
                break;
            }
            case FrameType.DATA: {
                onData(cast(DataFrame) frame, callback);
                break;
            }
            case FrameType.RST_STREAM: {
                onReset(cast(ResetFrame) frame, callback);
                break;
            }
            case FrameType.PUSH_PROMISE: {
                onPush(cast(PushPromiseFrame) frame, callback);
                break;
            }
            case FrameType.WINDOW_UPDATE: {
                onWindowUpdate(cast(WindowUpdateFrame) frame, callback);
                break;
            }
            default: {
                throw new UnsupportedOperationException("");
            }
        }
    }

    private void onHeaders(HeadersFrame frame, Callback callback) {
        if (updateClose(frame.isEndStream(), CloseStateEvent.RECEIVED))
            session.removeStream(this);
        callback.succeeded();
    }

    private void onData(DataFrame frame, Callback callback) {
        if (getRecvWindow() < 0) {
            // It's a bad client, it does not deserve to be
            // treated gently by just resetting the stream.
            session.close(ErrorCode.FLOW_CONTROL_ERROR, "stream_window_exceeded", Callback.NOOP);
            callback.failed(new IOException("stream_window_exceeded"));
            return;
        }

        // SPEC: remotely closed streams must be replied with a reset.
        if (isRemotelyClosed()) {
            reset(new ResetFrame(streamId, ErrorCode.STREAM_CLOSED_ERROR), Callback.NOOP);
            callback.failed(new EOFException("stream_closed"));
            return;
        }

        if (isReset()) {
            // Just drop the frame.
            callback.failed(new IOException("stream_reset"));
            return;
        }

        if (updateClose(frame.isEndStream(), CloseStateEvent.RECEIVED))
            session.removeStream(this);
        notifyData(this, frame, callback);
    }

    private void onReset(ResetFrame frame, Callback callback) {
        remoteReset = true;
        close();
        session.removeStream(this);
        notifyReset(this, frame, callback);
    }

    private void onPush(PushPromiseFrame frame, Callback callback) {
        // Pushed streams are implicitly locally closed.
        // They are closed when receiving an end-stream DATA frame.
        updateClose(true, CloseStateEvent.AFTER_SEND);
        callback.succeeded();
    }

    private void onWindowUpdate(WindowUpdateFrame frame, Callback callback) {
        callback.succeeded();
    }

    override
    bool updateClose(bool update, CloseStateEvent event) {
        version(HuntDebugMode) {
            tracef("Update close for %s update=%s event=%s", this, update, event);
        }

        if (!update)
            return false;

        switch (event) {
            case CloseStateEvent.RECEIVED:
                return updateCloseAfterReceived();
            case CloseStateEvent.BEFORE_SEND:
                return updateCloseBeforeSend();
            case CloseStateEvent.AFTER_SEND:
                return updateCloseAfterSend();
            default:
                return false;
        }
    }

    private bool updateCloseAfterReceived() {
        while (true) {
            CloseState current = closeState;
            switch (current) {
                case CloseState.NOT_CLOSED: {
                    if (closeState == current)
                    {
                        closeState = CloseState.REMOTELY_CLOSED;
                        return false;
                    }
                    break;
                }
                case CloseState.LOCALLY_CLOSING: {
                    // if (closeState.compareAndSet(current, CloseState.CLOSING)) {
                    if (closeState == current)
                    {
                        closeState = CloseState.CLOSING;
                        updateStreamCount(0, 1);
                        return false;
                    }
                    break;
                }
                case CloseState.LOCALLY_CLOSED: {
                    close();
                    return true;
                }
                default: {
                    return false;
                }
            }
        }
    }

    private bool updateCloseBeforeSend() {
        while (true) {
            CloseState current = closeState;
            switch (current) {
                case CloseState.NOT_CLOSED: {
                    // if (closeState.compareAndSet(current, CloseState.LOCALLY_CLOSING))
                    if (closeState == current)
                    {
                        closeState = CloseState.LOCALLY_CLOSING;
                        return false;
                    }
                    break;
                }
                case CloseState.REMOTELY_CLOSED: {
                    // if (closeState.compareAndSet(current, CloseState.CLOSING)) {
                    if (closeState == current)
                    {
                        closeState = CloseState.CLOSING;
                        updateStreamCount(0, 1);
                        return false;
                    }
                    break;
                }
                default: {
                    return false;
                }
            }
        }
    }

    private bool updateCloseAfterSend() {
        while (true) {
            CloseState current = closeState;
            switch (current) {
                case CloseState.NOT_CLOSED:
                case CloseState.LOCALLY_CLOSING: {
                    // if (closeState.compareAndSet(current, CloseState.LOCALLY_CLOSED))
                    if (closeState == current)
                    {
                        closeState = CloseState.LOCALLY_CLOSING;
                        return false;
                    }
                    break;
                }
                case CloseState.REMOTELY_CLOSED:
                case CloseState.CLOSING: {
                    close();
                    return true;
                }
                default: {
                    return false;
                }
            }
        }
    }

    int getSendWindow() {
        return sendWindow;
    }

    int getRecvWindow() {
        return recvWindow;
    }

    override
    int updateSendWindow(int delta) {
        int r = sendWindow; sendWindow += delta;
        return r;
        // return sendWindow.getAndAdd(delta);
    }

    override
    int updateRecvWindow(int delta) {
        int r = recvWindow; recvWindow += delta;
        return r;
    }

    override
    void close() {
        CloseState oldState = closeState;
        closeState = CloseState.CLOSED;
        if (oldState != CloseState.CLOSED) {
            int deltaClosing = oldState == CloseState.CLOSING ? -1 : 0;
            updateStreamCount(-1, deltaClosing);
            // onClose();
        }
    }

    private void updateStreamCount(int deltaStream, int deltaClosing) {
        (cast(HTTP2Session) session).updateStreamCount(isLocal(), deltaStream, deltaClosing);
    }

    private void notifyData(Stream stream, DataFrame frame, Callback callback) {
        Listener listener = this.listener;
        if (listener is null)
            return;
        try {
            listener.onData(stream, frame, callback);
        } catch (Exception x) {
            info("Failure while notifying listener " ~ listener.toString(), x);
        }
    }

    private void notifyReset(Stream stream, ResetFrame frame, Callback callback) {
        Listener listener = this.listener;
        if (listener is null)
            return;
        try {
            listener.onReset(stream, frame, callback);
        } catch (Exception x) {
            info("Failure while notifying listener " ~ listener.toString(), x);
        }
    }

    private bool notifyIdleTimeout(Stream stream, Exception failure) {
        Listener listener = this.listener;
        if (listener is null)
            return true;
        try {
            return listener.onIdleTimeout(stream, failure);
        } catch (Exception x) {
            info("Failure while notifying listener " ~ listener.toString(), x);
            return true;
        }
    }

    override
    string toString() {
        return format("%s@%x#%d{sendWindow=%s,recvWindow=%s,reset=%b,%s}", typeof(this).stringof,
                toHash(), getId(), sendWindow, recvWindow, isReset(), closeState);
    }
}
