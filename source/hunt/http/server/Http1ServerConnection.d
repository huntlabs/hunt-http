module hunt.http.server.Http1ServerConnection;

import hunt.http.server.HttpServerConnection;
import hunt.http.server.Http1ServerRequestHandler;
import hunt.http.server.Http1ServerTunnelConnection;
import hunt.http.server.Http2ServerConnection;
import hunt.http.server.ServerSessionListener;
import hunt.http.server.WebSocketHandler;

import hunt.http.codec.http.decode.HttpParser;
import hunt.http.codec.http.decode.SettingsBodyParser;
import hunt.http.codec.http.encode.HttpGenerator;
import hunt.http.codec.http.encode.PredefinedHttp1Response;

import hunt.http.codec.websocket.model.AcceptHash;
import hunt.http.codec.websocket.model.ExtensionConfig;
import hunt.http.codec.websocket.stream.WebSocketConnectionImpl;
import hunt.http.codec.websocket.stream.IOState;

import hunt.http.codec.http.frame.HeadersFrame;
import hunt.http.codec.http.frame.PrefaceFrame;
import hunt.http.codec.http.frame.SettingsFrame;

import hunt.http.codec.http.model;
import hunt.http.codec.http.stream;

// import hunt.http.util.Completable;

import hunt.http.HttpConnection;
import hunt.http.HttpField;
import hunt.http.HttpFields;
import hunt.http.HttpHeader;
import hunt.http.HttpMethod;
import hunt.http.HttpOptions;
import hunt.http.HttpOutputStream;
import hunt.http.HttpRequest;
import hunt.http.HttpResponse;
import hunt.http.HttpStatus;
import hunt.http.HttpVersion;

import hunt.http.WebSocketCommon;
import hunt.http.WebSocketConnection;
import hunt.http.WebSocketFrame;

import hunt.net.secure.SecureSession;
import hunt.net.Connection;

import hunt.collection.BufferUtils;
import hunt.collection.ByteBuffer;
import hunt.collection.List;

import hunt.io;
import hunt.Assert;
import hunt.Exceptions;
import hunt.concurrency.Promise;
import hunt.concurrency.FuturePromise;
import hunt.text.Common;
import hunt.util.ConverterUtils;

import hunt.logging;

import std.algorithm;
import std.array;
import std.base64;


/**
*/
class Http1ServerConnection : AbstractHttp1Connection, HttpServerConnection {

    private WebSocketHandler webSocketHandler;
    private ServerSessionListener serverSessionListener;
    private Http1ServerRequestHandler serverRequestHandler;
    private shared bool upgradeHttp2Complete = false;
    private shared bool upgradeWebSocketComplete = false;
    private Promise!HttpTunnelConnection tunnelConnectionPromise;

    this(HttpOptions config, Connection tcpSession, Http1ServerRequestHandler requestHandler,
            ServerSessionListener serverSessionListener, 
            WebSocketHandler webSocketHandler) {
        
        version (HUNT_DEBUG) 
            trace("Initializing Http1ServerConnection ...");
        super(config, tcpSession, requestHandler, null);
        requestHandler.connection = this;
        this.serverSessionListener = serverSessionListener;
        this.serverRequestHandler = requestHandler;
        this.webSocketHandler = webSocketHandler;
    }

    override protected HttpParser initHttpParser(HttpOptions config,
            HttpRequestParsingHandler requestHandler, HttpResponseParsingHandler responseHandler) {
        return new HttpParser(requestHandler, config.getMaxRequestHeadLength());
    }

    override HttpConnectionType getConnectionType() {
        return super.getConnectionType();
    }

    // override bool isSecured() {
    //     return super.isSecured();
    // }

    HttpParser getParser() {
        return parser;
    }

    HttpOptions getHttpOptions() {
        return config;
    }

    HttpRequest getRequest() {
        return serverRequestHandler.request;
    }

    HttpResponse getResponse() {
        return serverRequestHandler.response;
    }

    void response100Continue() {
        serverRequestHandler.outputStream.response100Continue();
    }

    private void responseH2c() {
        serverRequestHandler.outputStream.responseH2c();
    }

    override void upgradeHttpTunnel(Promise!HttpTunnelConnection tunnelConnectionPromise) {
        this.tunnelConnectionPromise = tunnelConnectionPromise;
    }

    override FuturePromise!HttpTunnelConnection upgradeHttpTunnel() {
        auto c = new FuturePromise!HttpTunnelConnection();
        tunnelConnectionPromise = c;
        return c;
    }

    Http1ServerTunnelConnection createHttpTunnel() {
        if (tunnelConnectionPromise !is null) {
            Http1ServerTunnelConnection tunnelConnection = new Http1ServerTunnelConnection(
                    _tcpSession, _httpVersion);
            _tcpSession.setAttribute(HttpConnection.NAME, tunnelConnection);
            tunnelConnectionPromise.succeeded(tunnelConnection);
            return tunnelConnection;
        } else {
            return null;
        }
    }

    bool directUpgradeHttp2(HttpRequest request) {
        version (HUNT_DEBUG) info("Upgrading to Http2");

        if (HttpMethod.PRI.isSame(request.getMethod())) {
            Http2ServerConnection http2ServerConnection = new Http2ServerConnection(config,
                    _tcpSession, serverSessionListener);
            _tcpSession.setAttribute(HttpConnection.NAME, http2ServerConnection);
            http2ServerConnection.getParser().directUpgrade();
            upgradeHttp2Complete = true;
            return true;
        } else {
            return false;
        }
    }

    bool upgradeProtocol(HttpRequest request, HttpResponse response,
            HttpOutputStream output, HttpConnection connection) {
        version (HUNT_HTTP_DEBUG) info("try upgrading protocol ...");                
        if(request is null)
            return false;
        switch (ProtocolHelper.from(request)) {
        case Protocol.H2: {
                if (upgradeHttp2Complete) {
                    throw new IllegalStateException("The connection has been upgraded HTTP2");
                }

                HttpField settingsField = request.getFields().getField(HttpHeader.HTTP2_SETTINGS);
                assert(settingsField !is null, "The http2 setting field must be not null.");

                // byte[] settings = Base64Utils.decodeFromUrlSafeString(settingsField.getValue());
                byte[] settings = cast(byte[]) Base64.decode(settingsField.getValue());
                version (HUNT_HTTP_DEBUG) {
                    tracef("the server received settings %s", ConverterUtils.toHexString(settings));
                }

                SettingsFrame settingsFrame = SettingsBodyParser.parseBody(
                        BufferUtils.toBuffer(settings));
                if (settingsFrame is null) {
                    throw new BadMessageException("settings frame parsing error");
                } else {
                    responseH2c();

                    Http2ServerConnection http2ServerConnection = new Http2ServerConnection(config,
                            _tcpSession,  serverSessionListener);
                    _tcpSession.setAttribute(HttpConnection.NAME, http2ServerConnection);
                    upgradeHttp2Complete = true;
                    http2ServerConnection.getParser().standardUpgrade();

                    serverSessionListener.onAccept(http2ServerConnection.getHttp2Session());
                    SessionSPI sessionSPI = http2ServerConnection.getSessionSPI();

                    sessionSPI.onFrame(new PrefaceFrame());
                    sessionSPI.onFrame(settingsFrame);
                    sessionSPI.onFrame(new HeadersFrame(1, request, null, true));
                }
                return true;
            }

        case Protocol.WEB_SOCKET: {
                if (upgradeWebSocketComplete) {
                    throw new IllegalStateException("The connection has been upgraded WebSocket");
                }

                assert(HttpMethod.GET.isSame(request.getMethod()),
                        "The method of the request MUST be GET in the websocket handshake.");
                assert(request.getHttpVersion() == HttpVersion.HTTP_1_1,
                        "The http version MUST be HTTP/1.1");

                bool accept = webSocketHandler.acceptUpgrade(request, response, output, connection);
                if (!accept) {
                    return false;
                }

                string key = request.getFields().get("Sec-WebSocket-Key");
                assert(!key.empty(), "Missing request header 'Sec-WebSocket-Key'");

                // dfmt off
                WebSocketConnectionImpl webSocketConnection = new WebSocketConnectionImpl(
                         _tcpSession,
                        null, webSocketHandler.getWebSocketPolicy(),
                        request, response, config);

                webSocketConnection.setNextIncomingFrames(new class IncomingFrames {

                    void incomingError(Exception t) {
                        version(HUNT_DEBUG) warning(t.msg);
                        version(HUNT_HTTP_DEBUG_MORE) warning(t);
                        webSocketHandler.onError(t, webSocketConnection);
                    }

                    void incomingFrame(WebSocketFrame frame) {
                        version(HUNT_HTTP_DEBUG_MORE) trace(BufferUtils.toDetailString(frame.getPayload()));
                        webSocketHandler.onFrame(frame, webSocketConnection);
                    }
                });
                
                IOState ioState = webSocketConnection.getIOState();
                ioState.addListener((WebSocketConnectionState state) {
                    version(HUNT_HTTP_DEBUG) info("State: ", state);
                    if(state == WebSocketConnectionState.CLOSED) {
                        webSocketHandler.onClosed(webSocketConnection);
                    }
                });

                ioState.onConnected();
                ioState.onOpened();

// dfmt on
                ExtensionConfig[] negotiatedExtensions = webSocketConnection.getExtensionNegotiator()
                    .negotiate(request);

                response.setStatus(HttpStatus.SWITCHING_PROTOCOLS_101);
                response.getFields().put(HttpHeader.UPGRADE, "WebSocket");
                response.getFields().add(HttpHeader.CONNECTION.asString(), "Upgrade");
                response.getFields().add(HttpHeader.SEC_WEBSOCKET_ACCEPT.asString(),
                        AcceptHash.hashKey(key));

                if (!negotiatedExtensions.empty) {
                    auto r = negotiatedExtensions.filter!(
                            e => e.getName() == ("permessage-deflate"));
                    if (!r.empty) {
                        r.front.getParameters().clear();
                    }
                    response.getFields().add(HttpHeader.SEC_WEBSOCKET_EXTENSIONS.asString(),
                            ExtensionConfig.toHeaderValue(negotiatedExtensions));
                }

                IOUtils.close(output);
                // output.close();
                _tcpSession.setAttribute(HttpConnection.NAME, webSocketConnection);
                upgradeWebSocketComplete = true;
                webSocketHandler.onOpen(webSocketConnection);
                return true;
            }
        default:
            return false;
        }
    }

    bool getUpgradeHttp2Complete() {
        return upgradeHttp2Complete;
    }

    bool getUpgradeWebSocketComplete() {
        return upgradeWebSocketComplete;
    }

    Promise!HttpTunnelConnection getTunnelConnectionPromise() {
        return tunnelConnectionPromise;
    }
}

/**
*/
class Http1ServerResponseOutputStream : AbstractHttp1OutputStream {

    private Http1ServerConnection connection;
    private HttpGenerator httpGenerator;

    this(HttpResponse response, Http1ServerConnection connection) {
        super(response, false);
        this.connection = connection;
        httpGenerator = new HttpGenerator(true, false);
    }

    Http1ServerConnection getHttp1ServerConnection() {
        return connection;
    }

    void responseH2c() {
        getSession().encode(BufferUtils.toBuffer(PredefinedHttp1Response.H2C_BYTES));
    }

    void response100Continue() {
        getSession().encode(BufferUtils.toBuffer(PredefinedHttp1Response.CONTINUE_100_BYTES));
    }

    override protected void generateHttpMessageSuccessfully() {
        version (HUNT_HTTP_DEBUG) {
            tracef("server session %s generates the HTTP message completely",
                    connection.getId());
        }

        HttpResponse response = connection.getResponse();
        HttpRequest request = connection.getRequest();

        string requestConnectionValue = "close";
        HttpVersion ver = HttpVersion.HTTP_1_1;
        if(request !is null) {
            requestConnectionValue = request.getFields().get(HttpHeader.CONNECTION);
            ver = request.getHttpVersion();
        }
        string responseConnectionValue = response.getFields().get(HttpHeader.CONNECTION);

        if (ver == HttpVersion.HTTP_1_1) { // the persistent connection is default in HTTP 1.1
            if ("close".equalsIgnoreCase(requestConnectionValue)
                    || "close".equalsIgnoreCase(responseConnectionValue)) {
                connection.close();
            } else {
                version (HUNT_HTTP_DEBUG) {
                    infof("the server %s connection %d is persistent",
                            response.getHttpVersion(), connection.getId());
                }
            }
        } else if (ver == HttpVersion.HTTP_1_0) {
            if ("keep-alive".equalsIgnoreCase(requestConnectionValue)
                    && "keep-alive".equalsIgnoreCase(responseConnectionValue)) {
                tracef("the server %s connection %s is persistent",
                        response.getHttpVersion(), connection.getId());
            } else {
                connection.close();
            }
        } else {
            throw new IllegalStateException(
                    "server response does not support the http version " ~ connection.getHttpVersion()
                    .toString());
        }
    }

    override protected void generateHttpMessageExceptionally(HttpGenerator.Result actualResult,
            HttpGenerator.State actualState, HttpGenerator.Result expectedResult,
            HttpGenerator.State expectedState) {
        errorf("http1 generator error, actual: [%s, %s], expected: [%s, %s]",
                actualResult, actualState, expectedResult, expectedState);
        throw new IllegalStateException("server generates http message exception.");
    }

    override protected ByteBuffer getHeaderByteBuffer() {
        return BufferUtils.allocate(connection.getHttpOptions().getMaxResponseHeadLength());
    }

    override protected ByteBuffer getTrailerByteBuffer() {
        return BufferUtils.allocate(connection.getHttpOptions()
                .getMaxResponseTrailerLength());
    }

    override protected Connection getSession() {
        return connection.getTcpConnection();
    }

    override protected HttpGenerator getHttpGenerator() {
        return httpGenerator;
    }

}
