module hunt.http.codec.http.stream.Http2Flusher;

import hunt.http.codec.http.stream.FlowControlStrategy;
import hunt.http.codec.http.stream.Http2Session;
import hunt.http.codec.http.stream.StreamSPI;

import hunt.http.codec.http.frame.Frame;
import hunt.http.codec.http.frame.FrameType;
import hunt.http.codec.http.frame.WindowUpdateFrame;

import hunt.collection;
import hunt.concurrency.Locker;
import hunt.concurrency.IteratingCallback;
import hunt.Exceptions;
import hunt.logging;
import hunt.net.Connection;
import hunt.util.Common;

import std.format;


/**
*/
class Http2Flusher : IteratingCallback {

    alias Action = IteratingCallback.Action;

    private Queue!(WindowEntry) windows;// = new ArrayDeque!()();
    private Deque!(Entry) frames;// = new ArrayDeque!()();
    private Queue!(Entry) entries;// = new ArrayDeque!()();
    private List!(Entry) actives;// = new ArrayList!()();
    private Http2Session session;
    private Queue!ByteBuffer buffers;// = new LinkedList!()();
    private Entry stalled;
    private Exception terminated;

    this(Http2Session session) {
        windows = new LinkedList!(WindowEntry)();
        frames = new LinkedList!(Entry)();
        entries = new LinkedList!(Entry)();
        actives = new ArrayList!(Entry)();
        buffers = new LinkedList!(ByteBuffer)();
        this.session = session;
    }

    void window(StreamSPI stream, WindowUpdateFrame frame) {
        Exception closed;
        synchronized (this) {
            closed = terminated;
            if (closed is null)
                windows.offer(new WindowEntry(stream, frame));
        }
        // Flush stalled data.
        if (closed is null)
            iterate();
    }

    bool prepend(Entry entry) {
        Exception e;
        synchronized (this) {
            e = terminated;
            if (e is null) {
                frames.offerFirst(entry);
                version(HUNT_DEBUG) {
                    tracef("Prepended %s, frames=%s", entry.toString(), frames.size());
                }
            }
        }
        if (e is null)
            return true;
        onClosed(entry, e);
        return false;
    }

    bool append(Entry entry) {
        Exception closed;
        synchronized (this) {
            closed = terminated;
            if (closed is null) {
                frames.offer(entry);
                version(HUNT_DEBUG) {
                    // tracef("Appended %s, frames=%s", entry.toString(), frames.size());
                }
            }
        }
        if (closed is null) {
            return true;
        }
        onClosed(entry, closed);
        return false;
    }

    private int getWindowQueueSize() {
        return windows.size();
    }

    int getFrameQueueSize() {
        return frames.size();
    }

    override
    protected Action process() {
        version(HUNT_DEBUG) {
            // tracef("Flushing %s", session.toString());
        }
        synchronized (this) {
            if (terminated !is null) {
                throw terminated;
            }

            while (!windows.isEmpty()) {
                WindowEntry entry = windows.poll();
                entry.perform();
            }

            foreach (Entry entry ; frames) {
                entries.offer(entry);
                actives.add(entry);
            }
            frames.clear();
        }


        if (entries.isEmpty()) {
            version(HUNT_DEBUG) {
                // tracef("Flushed %s", session.toString());
            }
            return Action.IDLE;
        }

        while (!entries.isEmpty()) {
            Entry entry = entries.poll();
            version(HUNT_DEBUG) {
                // tracef("Processing %s", entry.toString());
            }
            // If the stream has been reset or removed, don't send the frame.
            if (entry.isStale()) {
                version(HUNT_DEBUG) {
                    tracef("Stale %s", entry.toString());
                }
                continue;
            }

            try {
                if (entry.generate(buffers)) {
                    if (entry.dataRemaining() > 0)
                        entries.offer(entry);
                } else {
                    if (stalled is null)
                        stalled = entry;
                }
            } catch (Exception failure) {
                // Failure to generate the entry is catastrophic.
                version(HUNT_DEBUG) {
                    trace("Failure generating frame " ~ entry.frame.toString(), failure.toString());
                }
                failed(failure);
                return Action.SUCCEEDED;
            }
        }

        if (buffers.isEmpty()) {
            complete();
            return Action.IDLE;
        }

        version(HUNT_DEBUG) {
            tracef("Writing %s buffers (%s bytes) for %s frames %s",
                    buffers.size(), BufferUtils.remaining(buffers), actives.size(), actives.toString());
        }

        Connection tcpSession =  session.getEndPoint();
        foreach(ByteBuffer buffer; buffers) {
            tcpSession.encode(buffer);
        }
        this.succeeded();
        return Action.SCHEDULED;
    }

    override
    void succeeded() {
        version(HUNT_DEBUG) {
            tracef("Written %s frames for %s", actives.size(), actives.toString());
        }
        complete();

        super.succeeded();
    }

    private void complete() {
        buffers.clear();

        // actives.forEach(Entry::complete);
        foreach(Entry ac; actives)
            ac.complete();

        if (stalled !is null) {
            // We have written part of the frame, but there is more to write.
            // The API will not allow to send two data frames for the same
            // stream so we append the unfinished frame at the end to allow
            // better interleaving with other streams.
            int index = actives.indexOf(stalled);
            for (int i = index; i < actives.size(); ++i) {
                Entry entry = actives.get(i);
                if (entry.dataRemaining() > 0)
                    append(entry);
            }
            for (int i = 0; i < index; ++i) {
                Entry entry = actives.get(i);
                if (entry.dataRemaining() > 0)
                    append(entry);
            }
            stalled = null;
        }

        actives.clear();
    }

    override
    protected void onCompleteSuccess() {
        throw new IllegalStateException("");
    }

    override
    protected void onCompleteFailure(Exception x) {
        buffers.clear();

        Exception closed;
        synchronized (this) {
            closed = terminated;
            terminated = x;
            version(HUNT_DEBUG) {
                tracef("%s, active/queued=%s/%s", closed !is null ? "Closing" : "Failing", actives.size(), frames.size());
            }
            actives.addAll(frames);
            frames.clear();
        }

        foreach(Entry entry; actives)
            entry.failed(x);
        actives.clear();

        // If the failure came from within the
        // flusher, we need to close the connection.
        if (closed is null)
            session.abort(x);
    }

    void terminate(Exception cause) {
        Exception closed;
        synchronized (this) {
            closed = terminated;
            terminated = cause;
            version(HUNT_DEBUG) {
                tracef("%s", closed !is null ? "Terminated" : "Terminating");
            }
        }
        if (closed is null)
            iterate();
    }

    private void onClosed(Entry entry, Exception failure) {
        entry.failed(failure);
    }

    override
    string toString() {
        return format("%s[window_queue=%d,frame_queue=%d,actives=%d]",
                super.toString(),
                getWindowQueueSize(),
                getFrameQueueSize(),
                actives.size());
    }

    static abstract class Entry : NestedCallback {
        Frame frame;
        StreamSPI stream;

        protected this(Frame frame, StreamSPI stream, Callback callback) {
            super(callback);
            this.frame = frame;
            this.stream = stream;
        }

        int dataRemaining() {
            return 0;
        }

        protected abstract bool generate(Queue!ByteBuffer buffers);

        private void complete() {
            if (isStale())
                failed(new EofException("reset"));
            else
                succeeded();
        }

        override
        void failed(Exception x) {
            if (stream !is null) {
                stream.close();
                stream.getSession().removeStream(stream);
            }
            super.failed(x);
        }

        private bool isStale() {
            return !isProtocol() && stream !is null && stream.isReset();
        }

        private bool isProtocol() {
            switch (frame.getType()) {
                case FrameType.DATA:
                case FrameType.HEADERS:
                case FrameType.PUSH_PROMISE:
                case FrameType.CONTINUATION:
                    return false;
                case FrameType.PRIORITY:
                case FrameType.RST_STREAM:
                case FrameType.SETTINGS:
                case FrameType.PING:
                case FrameType.GO_AWAY:
                case FrameType.WINDOW_UPDATE:
                case FrameType.PREFACE:
                case FrameType.DISCONNECT:
                    return true;
                default:
                    throw new IllegalStateException("");
            }
        }

        override
        string toString() {
            return frame.toString();
        }
    }

    private class WindowEntry {
        private StreamSPI stream;
        private WindowUpdateFrame frame;

        this(StreamSPI stream, WindowUpdateFrame frame) {
            this.stream = stream;
            this.frame = frame;
        }

        void perform() {
            FlowControlStrategy flowControl = session.getFlowControlStrategy();
            flowControl.onWindowUpdate(session, stream, frame);
        }
    }

}
