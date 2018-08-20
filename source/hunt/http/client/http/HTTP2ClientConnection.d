module hunt.http.client.http.HTTP2ClientConnection;

import hunt.http.client.http.ClientHTTPHandler;
import hunt.http.client.http.HTTPClientConnection;
import hunt.http.client.http.HTTP2ClientResponseHandler;
import hunt.http.client.http.HTTP2ClientSession;

import hunt.http.codec.http.decode.Parser;
import hunt.http.codec.http.encode.Generator;
import hunt.http.codec.http.frame;
import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.model.HttpHeaderValue;
import hunt.http.codec.http.model.MetaData;
import hunt.http.codec.http.stream;
// import hunt.http.codec.websocket.model.IncomingFrames;
// import hunt.http.codec.websocket.stream.WebSocketConnection;
import hunt.http.codec.websocket.stream.WebSocketPolicy;

import hunt.net.ConnectionType;
import hunt.net.secure.SecureSession;
import hunt.net.Session;

import hunt.util.functional;
import hunt.util.concurrent.FuturePromise;
import hunt.util.concurrent.Promise;
// import hunt.util.concurrent.Scheduler;
import hunt.util.exception;
import hunt.container.BufferUtils;
import kiss.logger;

import hunt.util.exception;
import hunt.container;

import std.conv;

alias SessionListener = StreamSession.Listener;

class HTTP2ClientConnection : AbstractHTTP2Connection , HTTPClientConnection {
    void initialize(HTTP2Configuration config, Promise!(HTTPClientConnection) promise,
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

    this(HTTP2Configuration config, TcpSession tcpSession, SecureSession secureSession,
                                 SessionListener listener) {
        super(config, tcpSession, secureSession, listener);
    }

    override
    protected HTTP2Session initHTTP2Session(HTTP2Configuration config, FlowControlStrategy flowControl,
                                            SessionListener listener) {
        return new HTTP2ClientSession(null, this.tcpSession, this.generator, listener, flowControl, config.getStreamIdleTimeout());
    }

    override
    protected Parser initParser(HTTP2Configuration config) {
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

    Generator getGenerator() {
        return generator;
    }

    SessionSPI getSessionSPI() {
        return http2Session;
    }

    override
    void send(Request request, ClientHTTPHandler handler) {
        Promise!(HTTPOutputStream) promise = new class Promise!(HTTPOutputStream) {

            void succeeded(HTTPOutputStream output) {
                try {
                    output.close();
                } catch (IOException e) {
                    errorf("write data unsuccessfully", e);
                }

            }

            void failed(Exception x) {
                errorf("write data unsuccessfully", x);
            }

            string id() { return "HTTPOutputStream close"; }
        };

        this.request(request, true, promise, handler);
    }

    override
    void send(Request request, ByteBuffer buffer, ClientHTTPHandler handler) {
        send(request, [buffer], handler);
    }

    override
    void send(Request request, ByteBuffer[] buffers, ClientHTTPHandler handler) {
        long contentLength = BufferUtils.remaining(buffers);
        request.getFields().put(HttpHeader.CONTENT_LENGTH, contentLength.to!string);

        Promise!(HTTPOutputStream) promise = new class Promise!(HTTPOutputStream) {

            void succeeded(HTTPOutputStream output) {
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
    HTTPOutputStream sendRequestWithContinuation(MetaData.Request request, ClientHTTPHandler handler) {
        request.getFields().put(HttpHeader.EXPECT, HttpHeaderValue.CONTINUE);
        return getHTTPOutputStream(request, handler);
    }

    override
    HTTPOutputStream getHTTPOutputStream(Request request, ClientHTTPHandler handler) {
        FuturePromise!(HTTPOutputStream) promise = new FuturePromise!(HTTPOutputStream)();
        send(request, promise, handler);
        try {
            return promise.get();
        } catch (Exception e) {
            errorf("get http output stream unsuccessfully", e);
            return null;
        }
    }

    override
    void send(Request request, Promise!(HTTPOutputStream) promise, ClientHTTPHandler handler) {
        this.request(request, false, promise, handler);
    }

    void request(Request request, bool endStream,
                        Promise!(HTTPOutputStream) promise,
                        ClientHTTPHandler handler) {
        http2Session.newStream(new HeadersFrame(request, null, endStream),
                new HTTP2ClientResponseHandler.ClientStreamPromise(request, promise),
                new HTTP2ClientResponseHandler(request, handler, this));
    }

    override
    void upgradeHTTP2(Request request, SettingsFrame settings, Promise!(HTTPClientConnection) promise,
                             ClientHTTPHandler upgradeHandler,
                             ClientHTTPHandler http2ResponseHandler) {
        throw new CommonRuntimeException("The current connection version is http2, it does not need to upgrading.");
    }

    // override
    // void upgradeWebSocket(Request request, WebSocketPolicy policy, Promise!(WebSocketConnection) promise,
    //                              ClientHTTPHandler upgradeHandler, IncomingFrames incomingFrames) {
    //     throw new CommonRuntimeException("The current connection version is http2, it can not upgrade WebSocket.");
    // }

}
