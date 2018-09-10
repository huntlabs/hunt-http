module hunt.http.client.http.Http1ClientConnection;


import hunt.http.client.http.ClientHttpHandler;
import hunt.http.client.http.ClientHttp2SessionListener;
import hunt.http.client.http.HttpClientConnection;
import hunt.http.client.http.Http1ClientResponseHandler;
import hunt.http.client.http.Http2ClientConnection;
import hunt.http.client.http.Http2ClientResponseHandler;
import hunt.http.client.http.Http2ClientSession;

import hunt.http.codec.http.decode.HttpParser;
import hunt.http.codec.http.encode.HttpGenerator;
import hunt.http.codec.http.frame.SettingsFrame;
import hunt.http.codec.http.model;
import hunt.http.codec.http.stream;
import hunt.http.codec.websocket.model.IncomingFrames;
import hunt.http.codec.websocket.model.common;
import hunt.http.codec.websocket.stream.WebSocketConnection;
import hunt.http.codec.websocket.stream.WebSocketPolicy;
import hunt.http.codec.websocket.stream.WebSocketConnectionImpl;

import hunt.net.ConnectionType;
import hunt.net.secure.SecureSession;
import hunt.net.Session;

import hunt.util.Assert;
import hunt.io;
import hunt.util.codec;
import hunt.util.concurrent.Promise;
import hunt.util.exception;
import hunt.util.string;

import hunt.container;

import hunt.logging;

import std.array;
import std.base64;
import std.conv;
import std.random;
import std.socket;


alias HttpProtocol = hunt.http.codec.http.model.Protocol.Protocol;
alias SessionListener = StreamSession.Listener;

// import hunt.http.codec.websocket.model.WebSocketConstants.SPEC_VERSION;

/**
*/
class Http1ClientConnection : AbstractHttp1Connection , HttpClientConnection {

    private Promise!(WebSocketConnection) webSocketConnectionPromise;
    private IncomingFrames incomingFrames;
    private WebSocketPolicy policy;
    private Promise!(HttpClientConnection) http2ConnectionPromise;
    private Http2ClientConnection http2Connection;
    private ClientHttp2SessionListener http2SessionListener;
    private bool upgradeHttp2Complete = false; // new bool(false);
    private bool upgradeWebSocketComplete = false; // new bool(false);
    private ResponseHandlerWrap wrap;

    private static class ResponseHandlerWrap : ResponseHandler {

        private Http1ClientResponseHandler writing; // = new AtomicReference<)();
        private int status;
        private string reason;
        private Http1ClientConnection connection;

        void badMessage(BadMessageException failure) {
            badMessage(failure.getCode(), failure.getReason());
        }

        override
        void earlyEOF() {
            Http1ClientResponseHandler h = writing;
            if (h !is null) {
                h.earlyEOF();
            } else {
                IO.close(connection);
            }

            writing = null;
        }


        override
        void parsedHeader(HttpField field) {
            writing.parsedHeader(field);
        }

        override
        bool headerComplete() {
            return writing.headerComplete();
        }

        override
        bool content(ByteBuffer item) {
            return writing.content(item);
        }

        override
        bool contentComplete() {
            return writing.contentComplete();
        }

        override
        void parsedTrailer(HttpField field) {
            writing.parsedTrailer(field);
        }

        override
        bool messageComplete() {
            if (status == 100 && "Continue".equalsIgnoreCase(reason)) {
                tracef("client received the 100 Continue response");
                connection.getParser().reset();
                return true;
            } else {
                auto r = writing.messageComplete();
                writing = null;                
                return r;
            }
        }

        override
        void badMessage(int status, string reason) {
            Http1ClientResponseHandler h = writing;
            writing = null;                
            if (h !is null) {
                h.badMessage(status, reason);
            } else {
                IO.close(connection);
            }
        }

        override
        int getHeaderCacheSize() {
            return 1024;
        }

        override
        bool startResponse(HttpVersion ver, int status, string reason) {
            this.status = status;
            this.reason = reason;
            return writing.startResponse(ver, status, reason);
        }

    }

    this(Http2Configuration config, TcpSession tcpSession, SecureSession secureSession) {
        this(config, secureSession, tcpSession, new ResponseHandlerWrap());
    }

    private this(Http2Configuration config, SecureSession secureSession, TcpSession tcpSession,
                                  ResponseHandler responseHandler) {
        super(config, secureSession, tcpSession, null, responseHandler);
        wrap = cast(ResponseHandlerWrap) responseHandler;
        wrap.connection = this;
    }

    override
    protected HttpParser initHttpParser(Http2Configuration config, RequestHandler requestHandler,
                                        ResponseHandler responseHandler) {
        return new HttpParser(responseHandler, config.getMaxRequestHeadLength());
    }


    override
    ConnectionType getConnectionType() {
        return ConnectionType.HTTP1;
    }

    override
    bool isEncrypted() {
        return super.isEncrypted();
    }

    HttpParser getParser() {
        return parser;
    }

    Http2Configuration getHttp2Configuration() {
        return config;
    }

    override
    void upgradeHttp2(Request request, SettingsFrame settings, Promise!(HttpClientConnection) promise,
                             ClientHttpHandler upgradeHandler,
                             ClientHttpHandler http2ResponseHandler) {
        Promise!(Stream) initStream = new Http2ClientResponseHandler.ClientStreamPromise(request, new class DefaultPromise!(HttpOutputStream) {

            override
            void failed(Exception x) {
                errorf("Create client output stream exception", x);
            }
        });
        Stream.Listener initStreamListener = new Http2ClientResponseHandler(request, http2ResponseHandler, this);
        ClientHttp2SessionListener listener = new class ClientHttp2SessionListener {

            override
            Map!(int, int) onPreface(StreamSession session) {
                return settings.getSettings();
            }

        };
        upgradeHttp2(request, settings, promise, initStream, initStreamListener, listener, upgradeHandler);
    }

    void upgradeHttp2(Request request, SettingsFrame settings,
                             Promise!(HttpClientConnection) promise, Promise!(Stream) initStream,
                             Stream.Listener initStreamListener, ClientHttp2SessionListener listener,
                             ClientHttpHandler handler) {
        if (isEncrypted()) {
            throw new IllegalStateException("The TLS TCP connection must use ALPN to upgrade HTTP2");
        }

        this.http2ConnectionPromise = promise;
        this.http2SessionListener = listener;
        http2Connection = new class Http2ClientConnection {
            this() {
                super(getHttp2Configuration(),
                getTcpSession(), null, http2SessionListener);
            }
            override
            protected Http2Session initHttp2Session(Http2Configuration config, FlowControlStrategy flowControl,
                                                    StreamSession.Listener listener) {
                return Http2ClientSession.initSessionForUpgradingHTTP2(null, this.tcpSession, generator,
                        listener, flowControl, 3, config.getStreamIdleTimeout(), initStream,
                        initStreamListener);
            }
        };

        // generate http2 upgrading headers
        request.getFields().add(new HttpField(HttpHeader.CONNECTION, "Upgrade, HTTP2-Settings"));
        request.getFields().add(new HttpField(HttpHeader.UPGRADE, "h2c"));
        if (settings !is null) {
            List!(ByteBuffer) byteBuffers = http2Generator.control(settings);
            if (byteBuffers !is null && byteBuffers.size() > 0) {
                try  {
                    // ByteArrayOutputStream ot = new ByteArrayOutputStream();
                    // foreach (ByteBuffer buffer ; byteBuffers) {
                    //     ot.write(BufferUtils.toArray(buffer));
                    // }
                    Appender!(byte[]) ot;
                    foreach (ByteBuffer buffer ; byteBuffers) {
                        byte[] bufferArray = BufferUtils.toArray(buffer);
                        // writeln("before1:\t" ~ TypeUtils.toHexString(bufferArray));
                        // writefln("before1:\t%(%02X %)" , bufferArray);
                        ot.put(bufferArray);
                    }
                    byte[] settingsFrame = ot.data; //ot.toByteArray();
                    byte[] settingsPayload = new byte[settingsFrame.length - 9];
                    // System.arraycopy(settingsFrame, 9, settingsPayload, 0, settingsPayload.length);
                    settingsPayload[0 .. settingsPayload.length] = settingsFrame[9 .. 9+settingsPayload.length];

                    request.getFields().add(new HttpField(HttpHeader.HTTP2_SETTINGS, 
                    // Base64Utils.encodeToUrlSafeString(settingsPayload)
                    Base64URL.encode(settingsPayload)
                    ));
                } catch (IOException e) {
                    errorf("generate http2 upgrading settings exception", e);
                }
            } else {
                request.getFields().add(new HttpField(HttpHeader.HTTP2_SETTINGS, ""));
            }
        } else {
            request.getFields().add(new HttpField(HttpHeader.HTTP2_SETTINGS, ""));
        }

        send(request, handler);
    }

    bool upgradeProtocolComplete(MetaData.Request request, MetaData.Response response) {
        switch (ProtocolHelper.from(response)) {
            case HttpProtocol.H2: {
                if (http2ConnectionPromise !is null && http2SessionListener !is null && http2Connection !is null) {
                    upgradeHttp2Complete = true;
                    getTcpSession().attachObject(http2Connection);
                    http2SessionListener.setConnection(http2Connection);
                    http2Connection.initialize(getHttp2Configuration(), http2ConnectionPromise, http2SessionListener);
                    return true;
                } else {
                    resetUpgradeProtocol();
                    return false;
                }
            }
            case HttpProtocol.WEB_SOCKET: {
                if (webSocketConnectionPromise !is null && incomingFrames !is null && policy !is null) {
                    upgradeWebSocketComplete = true;
                    WebSocketConnection webSocketConnection = new WebSocketConnectionImpl(
                            secureSession, tcpSession,
                            incomingFrames, policy,
                            request, response, config);
                    getTcpSession().attachObject(cast(Object)webSocketConnection);
                    webSocketConnectionPromise.succeeded(webSocketConnection);
                    return true;
                } else {
                    resetUpgradeProtocol();
                    return false;
                }
            }
            default:
                resetUpgradeProtocol();
                return false;
        }
    }

    private void resetUpgradeProtocol() {
        if (http2ConnectionPromise !is null) {
            http2ConnectionPromise.failed(new IllegalStateException("upgrade h2 failed"));
            http2ConnectionPromise = null;
        }
        http2SessionListener = null;
        http2Connection = null;
        if (webSocketConnectionPromise !is null) {
            webSocketConnectionPromise.failed(new IllegalStateException("The websocket handshake failed"));
            webSocketConnectionPromise = null;
        }
        incomingFrames = null;
        policy = null;
    }

    override
    void upgradeWebSocket(Request request, WebSocketPolicy policy, Promise!(WebSocketConnection) promise,
                                 ClientHttpHandler upgradeHandler, IncomingFrames incomingFrames) {
        assert(HttpMethod.GET.asString() == request.getMethod(), 
            "The method of the request MUST be GET in the websocket handshake.");

        assert(policy.getBehavior() == WebSocketBehavior.CLIENT, 
            "The websocket behavior MUST be client");

        request.getFields().put(HttpHeader.SEC_WEBSOCKET_VERSION, WebSocketConstants.SPEC_VERSION.to!string());
        request.getFields().put(HttpHeader.UPGRADE, "websocket");
        request.getFields().put(HttpHeader.CONNECTION, "Upgrade");
        request.getFields().put(HttpHeader.SEC_WEBSOCKET_KEY, genRandomKey());
        webSocketConnectionPromise = promise;
        this.incomingFrames = incomingFrames;
        this.policy = policy;
        send(request, upgradeHandler);
    }

    private string genRandomKey() {
        byte[] bytes = new byte[16];
        // ThreadLocalRandom.current().nextBytes(bytes);
        auto rnd = Random(2018);
        for(int i; i< bytes.length; i++)
            bytes[i] = cast(byte) uniform(byte.min, byte.max, rnd);
        return cast(string)(B64Code.encode(bytes));
    }

    override
    HttpOutputStream sendRequestWithContinuation(Request request, ClientHttpHandler handler) {
        request.getFields().put(HttpHeader.EXPECT, HttpHeaderValue.CONTINUE);
        HttpOutputStream outputStream = getHttpOutputStream(request, handler);
        try {
            outputStream.commit();
        } catch (IOException e) {
            errorf("client generates the HTTP message exception", e);
        }
        return outputStream;
    }

    override
    void send(Request request, ClientHttpHandler handler) {
        try  {
            tracef("client request and does not send data");
            HttpOutputStream output = getHttpOutputStream(request, handler);
            output.close();
        } catch (Exception e) {
            errorf("client generates the HTTP message exception", e);
        }
    }

    override
    void send(Request request, ByteBuffer buffer, ClientHttpHandler handler) {
        try  {
            HttpOutputStream output = getHttpOutputStream(request, handler);
            if (buffer !is null) {
                output.writeWithContentLength(buffer);
            }
        } catch (IOException e) {
            errorf("client generates the HTTP message exception", e);
        }
    }

    override
    void send(Request request, ByteBuffer[] buffers, ClientHttpHandler handler) {
        try  {
            HttpOutputStream output = getHttpOutputStream(request, handler);
            if (buffers !is null) {
                output.writeWithContentLength(buffers);
            }
        } catch (IOException e) {
            errorf("client generates the HTTP message exception", e);
        }
    }

    override
    HttpOutputStream getHttpOutputStream(Request request, ClientHttpHandler handler) {
        Http1ClientResponseHandler http1ClientResponseHandler = new Http1ClientResponseHandler(handler);
        checkWrite(request, http1ClientResponseHandler);
        http1ClientResponseHandler.outputStream = new Http1ClientRequestOutputStream(this, wrap.writing.request);
        return http1ClientResponseHandler.outputStream;
    }

    override
    void send(Request request, Promise!(HttpOutputStream) promise, ClientHttpHandler handler) {
        promise.succeeded(getHttpOutputStream(request, handler));
    }

    static class Http1ClientRequestOutputStream : AbstractHttp1OutputStream {

        private Http1ClientConnection connection;
        private HttpGenerator httpGenerator;

        private this(Http1ClientConnection connection, Request request) {
            super(request, true);
            this.connection = connection;
            httpGenerator = new HttpGenerator();
        }

        override
        protected void generateHttpMessageSuccessfully() {
            tracef("client session %s generates the HTTP message completely", connection.tcpSession.getSessionId());
        }

        override
        protected void generateHttpMessageExceptionally(HttpGenerator.Result actualResult,
                                                        HttpGenerator.State actualState,
                                                        HttpGenerator.Result expectedResult,
                                                        HttpGenerator.State expectedState) {
            errorf("http1 generator error, actual: [%s, %s], expected: [%s, %s]", actualResult, actualState, expectedResult, expectedState);
            throw new IllegalStateException("client generates http message exception.");
        }

        override
        protected ByteBuffer getHeaderByteBuffer() {
            return BufferUtils.allocate(connection.getHttp2Configuration().getMaxRequestHeadLength());
        }

        override
        protected ByteBuffer getTrailerByteBuffer() {
            return BufferUtils.allocate(connection.getHttp2Configuration().getMaxRequestTrailerLength());
        }

        override
        protected TcpSession getSession() {
            return connection.getTcpSession();
        }

        override
        protected HttpGenerator getHttpGenerator() {
            return httpGenerator;
        }
    }

    private void checkWrite(Request request, Http1ClientResponseHandler handler) {
        assert(request, "The http client request is null.");
        assert(handler, "The http1 client response handler is null.");
        assert(isOpen(), "The current connection " ~ tcpSession.getSessionId().to!string ~ " has been closed.");
        assert(!upgradeHttp2Complete, "The current connection " ~ tcpSession.getSessionId().to!string ~ " has upgraded HTTP2.");
        assert(!upgradeWebSocketComplete, "The current connection " ~ tcpSession.getSessionId().to!string ~ " has upgraded WebSocket.");

        if (wrap.writing is null) {
            wrap.writing = handler;
            request.getFields().put(HttpHeader.HOST, tcpSession.getRemoteAddress().toAddrString());
            handler.connection = this;
            handler.request = request;
        } else {
            throw new WritePendingException("");
        }
    }

    override
    void close() {
        if (isOpen()) {
            super.close();
        }
    }

    override
    bool isClosed() {
        return !isOpen();
    }

    override
    bool isOpen() {
        version(HuntDebugMode) {
            tracef("Connection status: isOpen=%s, upgradeHttp2Complete=%s, upgradeWebSocketComplete=%s", 
                tcpSession.isOpen(), upgradeHttp2Complete, upgradeWebSocketComplete);
        }
        return tcpSession.isOpen() && !upgradeHttp2Complete && !upgradeWebSocketComplete;
    }

    bool getUpgradeHttp2Complete() {
        return upgradeHttp2Complete;
    }

    bool getUpgradeWebSocketComplete() {
        return upgradeWebSocketComplete;
    }
}
