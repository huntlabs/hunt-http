module hunt.http.client.Http2ClientConnection;

import hunt.http.client.ClientHttpHandler;
import hunt.http.client.HttpClientConnection;
import hunt.http.client.Http2ClientResponseHandler;
import hunt.http.client.Http2ClientSession;

import hunt.http.codec.http.decode.Parser;
import hunt.http.codec.http.encode.Http2Generator;
import hunt.http.codec.http.frame;
import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.model.HttpHeaderValue;
import hunt.http.codec.http.model.MetaData;
import hunt.http.codec.http.stream;
import hunt.http.codec.websocket.model.IncomingFrames;
import hunt.http.codec.websocket.stream.WebSocketConnection;
import hunt.http.codec.websocket.stream.WebSocketPolicy;

import hunt.container;
import hunt.logging;
import hunt.net.ConnectionType;
import hunt.net.secure.SecureSession;
import hunt.net.Session;

import hunt.util.functional;
import hunt.concurrent.FuturePromise;
import hunt.concurrent.Promise;
// import hunt.concurrent.Scheduler;
import hunt.lang.exception;

import std.conv;

alias SessionListener = StreamSession.Listener;

class Http2ClientConnection : AbstractHttp2Connection , HttpClientConnection {
    void initialize(Http2Configuration config, Promise!(HttpClientConnection) promise,
                           SessionListener listener) {
        Map!(int, int) settings = listener.onPreface(getHttp2Session());
        if (settings is null) {
            settings = Collections.emptyMap!(int, int)();
        }
        PrefaceFrame prefaceFrame = new PrefaceFrame();
        SettingsFrame settingsFrame = new SettingsFrame(settings, false);
        SessionSPI sessionSPI = getSessionSPI();
        int windowDelta = config.getInitialSessionRecvWindow() - FlowControlStrategy.DEFAULT_WINDOW_SIZE;
        Callback callback = new class NoopCallback {

            override
            void succeeded() {
                promise.succeeded(this.outer);
            }

            override
            void failed(Exception x) {
                this.outer.close();
                promise.failed(x);
            }
        };

        if (windowDelta > 0) {
            sessionSPI.updateRecvWindow(windowDelta);
            sessionSPI.frames(null, callback, prefaceFrame, settingsFrame, new WindowUpdateFrame(0, windowDelta));
        } else {
            sessionSPI.frames(null, callback, prefaceFrame, settingsFrame);
        }

        // TODO: Tasks pending completion -@Administrator at 2018-7-16 14:41:31
        // 
        // Scheduler.Future pingFuture = scheduler.scheduleAtFixedRate(() => getHttp2Session().ping(new PingFrame(false), new class Callback {
        //     void succeeded() {
        //         info("The session %s sent ping frame success", getSessionId());
        //     }

        //     void failed(Throwable x) {
        //         warningf("the session %s sends ping frame failure. %s", getSessionId(), x.getMessage());
        //     }
        // }), config.getHttp2PingInterval(), config.getHttp2PingInterval(), TimeUnit.MILLISECONDS);

        // onClose(c => pingFuture.cancel());
    }

    this(Http2Configuration config, TcpSession tcpSession, SecureSession secureSession,
                                 SessionListener listener) {
        super(config, tcpSession, secureSession, listener);
    }

    override
    protected Http2Session initHttp2Session(Http2Configuration config, FlowControlStrategy flowControl,
                                            SessionListener listener) {
        return new Http2ClientSession(null, this.tcpSession, this.generator, listener, flowControl, config.getStreamIdleTimeout());
    }

    override
    protected Parser initParser(Http2Configuration config) {
        return new Parser(http2Session, config.getMaxDynamicTableSize(), config.getMaxRequestHeadLength());
    }

    
    override
    ConnectionType getConnectionType() {
        return super.getConnectionType();
    }

    override
    bool isEncrypted() {
        return super.isEncrypted();
    }


    Parser getParser() {
        return parser;
    }

    Http2Generator getGenerator() {
        return generator;
    }

    SessionSPI getSessionSPI() {
        return http2Session;
    }

    override
    void send(Request request, ClientHttpHandler handler) {
        Promise!(HttpOutputStream) promise = new class Promise!(HttpOutputStream) {

            void succeeded(HttpOutputStream output) {
                try {
                    output.close();
                } catch (IOException e) {
                    errorf("write data unsuccessfully", e);
                }

            }

            void failed(Exception x) {
                errorf("write data unsuccessfully", x);
            }

            string id() { return "HttpOutputStream close"; }
        };

        this.request(request, true, promise, handler);
    }

    override
    void send(Request request, ByteBuffer buffer, ClientHttpHandler handler) {
        send(request, [buffer], handler);
    }

    override
    void send(Request request, ByteBuffer[] buffers, ClientHttpHandler handler) {
        long contentLength = BufferUtils.remaining(buffers);
        request.getFields().put(HttpHeader.CONTENT_LENGTH, contentLength.to!string);

        Promise!(HttpOutputStream) promise = new class Promise!(HttpOutputStream) {

            void succeeded(HttpOutputStream output) {
                try {
                    output.writeWithContentLength(buffers);
                } catch (IOException e) {
                    errorf("write data unsuccessfully", e);
                }
            }

            void failed(Exception x) {
                errorf("write data unsuccessfully", x);
            }

            string id() { return "writeWithContentLength"; }
        };

        send(request, promise, handler);
    }

    override
    HttpOutputStream sendRequestWithContinuation(HttpRequest request, ClientHttpHandler handler) {
        request.getFields().put(HttpHeader.EXPECT, HttpHeaderValue.CONTINUE);
        return getHttpOutputStream(request, handler);
    }

    override
    HttpOutputStream getHttpOutputStream(Request request, ClientHttpHandler handler) {
        FuturePromise!(HttpOutputStream) promise = new FuturePromise!(HttpOutputStream)();
        send(request, promise, handler);
        try {
            return promise.get();
        } catch (Exception e) {
            errorf("get http output stream unsuccessfully", e);
            return null;
        }
    }

    override
    void send(Request request, Promise!(HttpOutputStream) promise, ClientHttpHandler handler) {
        this.request(request, false, promise, handler);
    }

    void request(Request request, bool endStream,
                        Promise!(HttpOutputStream) promise,
                        ClientHttpHandler handler) {
        http2Session.newStream(new HeadersFrame(request, null, endStream),
                new Http2ClientResponseHandler.ClientStreamPromise(request, promise),
                new Http2ClientResponseHandler(request, handler, this));
    }

    override
    void upgradeHttp2(Request request, SettingsFrame settings, Promise!(HttpClientConnection) promise,
                             ClientHttpHandler upgradeHandler,
                             ClientHttpHandler http2ResponseHandler) {
        throw new CommonRuntimeException("The current connection version is http2, it does not need to upgrading.");
    }

    override
    void upgradeWebSocket(Request request, WebSocketPolicy policy, Promise!(WebSocketConnection) promise,
                                 ClientHttpHandler upgradeHandler, IncomingFrames incomingFrames) {
        throw new CommonRuntimeException("The current connection version is http2, it can not upgrade WebSocket.");
    }

}
