module hunt.http.client.Http2ClientSession;

import hunt.http.codec.http.encode.Http2Generator;
import hunt.http.codec.http.frame.HeadersFrame;
import hunt.http.codec.http.frame.PushPromiseFrame;
import hunt.http.codec.http.stream;

import hunt.net.Connection;

import hunt.util.Common;
import hunt.concurrency.Promise;
import hunt.concurrency.Scheduler;
import hunt.logging;


class Http2ClientSession : Http2Session {
    
    this(Scheduler scheduler, Connection endPoint, Http2Generator generator,
                              Listener listener, FlowControlStrategy flowControl, int streamIdleTimeout) {
        super(scheduler, endPoint, generator, listener, flowControl, 1, streamIdleTimeout);
    }

    static Http2ClientSession initSessionForUpgradingHTTP2(Scheduler scheduler, Connection endPoint,
        Http2Generator generator, Listener listener, FlowControlStrategy flowControl, 
        int initialStreamId, int streamIdleTimeout, Promise!(Stream) initStream, 
        Stream.Listener initStreamListener) {

        Http2ClientSession session = new Http2ClientSession(scheduler, endPoint, generator, listener, flowControl,
                initialStreamId, streamIdleTimeout);
        StreamSPI stream = session.createLocalStream(1, initStream);
        stream.setListener(initStreamListener);
        stream.updateClose(true, CloseStateEvent.AFTER_SEND);
        initStream.succeeded(stream);
        return session;
    }

    private this(Scheduler scheduler, Connection endPoint, Http2Generator generator,
                               Listener listener, FlowControlStrategy flowControl, int initialStreamId, int streamIdleTimeout) {
        super(scheduler, endPoint, generator, listener, flowControl, initialStreamId, streamIdleTimeout);
    }

    override
    void onHeaders(HeadersFrame frame) {
        version(HUNT_DEBUG) {
            tracef("Client received %s", frame);
        }

        auto stream = getStream(frame.getStreamId());
        if(stream !is null)
        {
            stream.process(frame, Callback.NOOP);
            notifyHeaders(stream, frame);
        }

        // Optional.ofNullable(getStream(frame.getStreamId()))
        //         .ifPresent(stream -) {
        //             stream.process(frame, Callback.NOOP);
        //             notifyHeaders(stream, frame);
        //         });
    }

    // override
    void onPushPromise(PushPromiseFrame frame) {
        version(HUNT_DEBUG) {
            tracef("Client received %s", frame);
        }

        int streamId = frame.getStreamId();
        int pushStreamId = frame.getPromisedStreamId();
        StreamSPI stream = getStream(streamId);
        if (stream is null) {
            version(HUNT_DEBUG)
                tracef("Ignoring %s, stream #%s not found", frame, streamId);
        } else {
            StreamSPI pushStream = createRemoteStream(pushStreamId);
            pushStream.process(frame, Callback.NOOP);
            Stream.Listener listener = notifyPush(stream, pushStream, frame);
            pushStream.setListener(listener);
        }
    }

    private Stream.Listener notifyPush(StreamSPI stream, StreamSPI pushStream, PushPromiseFrame frame) {
        Stream.Listener listener = stream.getListener();
        if (listener is null)
            return null;
        try {
            return listener.onPush(pushStream, frame);
        } catch (Throwable x) {
            errorf("Failure while notifying listener %s", x, listener);
            return null;
        }
    }
}
