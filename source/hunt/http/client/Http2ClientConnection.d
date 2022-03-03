module hunt.http.client.Http2ClientConnection;

import hunt.http.client.ClientHttpHandler;
import hunt.http.client.HttpClientConnection;
import hunt.http.client.Http2ClientResponseHandler;
import hunt.http.client.Http2ClientSession;

import hunt.http.codec.http.decode.Parser;
import hunt.http.codec.http.encode.Http2Generator;
import hunt.http.codec.http.frame;
import hunt.http.codec.http.stream;

import hunt.http.HttpConnection;
import hunt.http.HttpHeader;
import hunt.http.HttpOptions;
import hunt.http.HttpOutputStream;
import hunt.http.HttpRequest;
import hunt.http.WebSocketConnection;
import hunt.http.WebSocketPolicy;
import hunt.http.Util;

import hunt.collection;
import hunt.concurrency.Delayed;
import hunt.logging;
import hunt.net.secure.SecureSession;
import hunt.net.Connection;

import hunt.concurrency.FuturePromise;
import hunt.concurrency.Promise;
import hunt.Exceptions;
import hunt.util.Common;
import hunt.util.Runnable;

import core.time;
import std.conv;

alias SessionListener = StreamSession.Listener;

/**
 * 
 */
class Http2ClientConnection : AbstractHttp2Connection , HttpClientConnection {
    void initialize(HttpOptions config, Promise!(HttpClientConnection) promise,
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

        executor = CommonUtil.scheduler();
        executor.setRemoveOnCancelPolicy(true);
        ScheduledFuture!(void) pingFuture = executor.scheduleWithFixedDelay(new class Runnable {
            void run() {
                PingFrame pingFrame = new PingFrame(false);

                getHttp2Session().ping(pingFrame, new class NoopCallback {
                    override void succeeded() {
                        version(HUNT_HTTP_DEBUG) infof("The session %s sent ping frame success", getId());
                    }

                    override void failed(Exception x) {
                        debug warningf("the session %s sends ping frame failure. %s", getId(), x.msg);
                        version(HUNT_HTTP_DEBUG)  warning(x);
                    }
                });
            }
        }, 
        
        msecs(config.getHttp2PingInterval()), 
        msecs(config.getHttp2PingInterval()));

        onClose( (c) { pingFuture.cancel(false); });        
    }

    this(HttpOptions config, Connection tcpSession, SessionListener listener) {
        super(config, tcpSession, listener);
    }

    override
    protected Http2Session initHttp2Session(HttpOptions config, FlowControlStrategy flowControl,
                                            SessionListener listener) {
        return new Http2ClientSession(null, this._tcpSession, this.generator, listener, flowControl, config.getStreamIdleTimeout());
    }

    override
    protected Parser initParser(HttpOptions config) {
        return new Parser(http2Session, config.getMaxDynamicTableSize(), config.getMaxRequestHeadLength());
    }

    
    override
    HttpConnectionType getConnectionType() {
        return super.getConnectionType();
    }

    // override
    // bool isSecured() {
    //     return super.isSecured();
    // }


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
    void send(HttpRequest request, ClientHttpHandler handler) {
        Promise!(HttpOutputStream) promise = new class Promise!(HttpOutputStream) {

            bool succeeded(HttpOutputStream output) {
                try {
                    output.close();
                    return true;
                } catch (IOException e) {
                    errorf("write data unsuccessfully", e);
                    return false;
                }

            }

            bool failed(Throwable x) {
                errorf("write data unsuccessfully", x);
                return true;
            }

            string id() { return "HttpOutputStream close"; }
        };

        this.request(request, true, promise, handler);
    }

    override
    void send(HttpRequest request, ByteBuffer buffer, ClientHttpHandler handler) {
        send(request, [buffer], handler);
    }

    override
    void send(HttpRequest request, ByteBuffer[] buffers, ClientHttpHandler handler) {
        long contentLength = BufferUtils.remaining(buffers);
        request.getFields().put(HttpHeader.CONTENT_LENGTH, contentLength.to!string);

        Promise!(HttpOutputStream) promise = new class Promise!(HttpOutputStream) {

            bool succeeded(HttpOutputStream output) {
                try {
                    output.writeWithContentLength(buffers);
                    return true;
                } catch (IOException e) {
                    errorf("write data unsuccessfully", e);
                    return false;
                }
            }

            bool failed(Throwable x) {
                errorf("write data unsuccessfully", x);
                return true;
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
    HttpOutputStream getHttpOutputStream(HttpRequest request, ClientHttpHandler handler) {
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
    void send(HttpRequest request, Promise!(HttpOutputStream) promise, ClientHttpHandler handler) {
        this.request(request, false, promise, handler);
    }

    void request(HttpRequest request, bool endStream,
                        Promise!(HttpOutputStream) promise,
                        ClientHttpHandler handler) {
        http2Session.newStream(new HeadersFrame(request, null, endStream),
                new Http2ClientResponseHandler.ClientStreamPromise(request, promise),
                new Http2ClientResponseHandler(request, handler, this));
    }

    override
    void upgradeHttp2(HttpRequest request, SettingsFrame settings, Promise!(HttpClientConnection) promise,
                             ClientHttpHandler upgradeHandler,
                             ClientHttpHandler http2ResponseHandler) {
        throw new CommonRuntimeException("The current connection version is http2, it does not need to upgrading.");
    }

    override
    void upgradeWebSocket(HttpRequest request, WebSocketPolicy policy, Promise!(WebSocketConnection) promise,
                                 ClientHttpHandler upgradeHandler, IncomingFrames incomingFrames) {
        throw new CommonRuntimeException("The current connection version is http2, it can not upgrade WebSocket.");
    }

}
