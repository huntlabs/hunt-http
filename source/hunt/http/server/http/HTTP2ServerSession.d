module hunt.http.server.http.HTTP2ServerSession;

import hunt.http.server.http.ServerSessionListener;

import hunt.http.codec.http.decode.ServerParser;
import hunt.http.codec.http.encode.Generator;
import hunt.http.codec.http.frame;
import hunt.http.codec.http.model.MetaData;
import hunt.http.codec.http.stream;

import hunt.util.functional;
import hunt.util.concurrent.Scheduler;

import kiss.logger;

import hunt.container.Collections;
import hunt.container.Map;

import hunt.net.Session;

class HTTP2ServerSession : HTTP2Session , ServerParser.Listener {
    
    private ServerSessionListener listener;

    this(Scheduler scheduler, TcpSession endPoint, Generator generator,
                              ServerSessionListener listener, FlowControlStrategy flowControl, int streamIdleTimeout) {
        super(scheduler, endPoint, generator, listener, flowControl, 2, streamIdleTimeout);
        this.listener = listener;
    }

    override
    void onPreface() {
        // SPEC: send a SETTINGS frame upon receiving the preface.
        Map!(int, int) settings = notifyPreface(this);
        if (settings is null)
            settings = Collections.emptyMap!(int, int)();
        SettingsFrame settingsFrame = new SettingsFrame(settings, false);

        WindowUpdateFrame windowFrame = null;
        int sessionWindow = getInitialSessionRecvWindow() - FlowControlStrategy.DEFAULT_WINDOW_SIZE;
        if (sessionWindow > 0) {
            updateRecvWindow(sessionWindow);
            windowFrame = new WindowUpdateFrame(0, sessionWindow);
        }

        if (windowFrame is null)
            frames(null, Callback.NOOP, settingsFrame, Frame.EMPTY_ARRAY);
        else
            frames(null, Callback.NOOP, settingsFrame, windowFrame);
    }

    override
    void onHeaders(HeadersFrame frame) {
        version(HuntDebugMode) {
            tracef("Server received %s", frame);
        }

        MetaData metaData = frame.getMetaData();
        if (metaData.isRequest()) {
            StreamSPI stream = createRemoteStream(frame.getStreamId());
            if (stream !is null) {
                stream.process(frame, Callback.NOOP);
                Stream.Listener listener = notifyNewStream(stream, frame);
                stream.setListener(listener);
            }
        } else {
            if (frame.isEndStream()) { // The trailer frame
                StreamSPI st = cast(StreamSPI)getStream(frame.getStreamId());
                if(st !is null)
                {
                    st.process(frame, Callback.NOOP);
                    notifyHeaders(st, frame);
                }
            } else {
                onConnectionFailure(ErrorCode.INTERNAL_ERROR, "invalid_request");
            }
        }
    }

    override
    void onPushPromise(PushPromiseFrame frame) {
        onConnectionFailure(ErrorCode.PROTOCOL_ERROR, "push_promise");
    }

    private Map!(int, int) notifyPreface(StreamSession session) {
        try {
            return listener.onPreface(session);
        } catch (Throwable x) {
            errorf("Failure while notifying listener %s", x, listener);
            return null;
        }
    }

    override
    void onFrame(Frame frame) {
        switch (frame.getType()) {
            case FrameType.PREFACE:
                onPreface();
                break;
            case FrameType.SETTINGS:
                // SPEC: the required reply to this SETTINGS frame is the 101
                // response.
                onSettings(cast(SettingsFrame) frame, false);
                break;
            case FrameType.HEADERS:
                onHeaders(cast(HeadersFrame) frame);
                break;
            default:
                super.onFrame(frame);
                break;
        }
    }
}
