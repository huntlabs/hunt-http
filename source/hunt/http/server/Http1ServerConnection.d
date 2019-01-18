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

import hunt.http.codec.websocket.frame.Frame;
import hunt.http.codec.websocket.model.AcceptHash;
import hunt.http.codec.websocket.model.ExtensionConfig;
import hunt.http.codec.websocket.model.IncomingFrames;
import hunt.http.codec.websocket.stream.WebSocketConnectionImpl;

import hunt.http.codec.http.frame.HeadersFrame;
import hunt.http.codec.http.frame.PrefaceFrame;
import hunt.http.codec.http.frame.SettingsFrame;

import hunt.http.codec.http.model;
import hunt.http.codec.http.stream;

import hunt.net.ConnectionType;
import hunt.net.secure.SecureSession;
import hunt.net.Session;

import hunt.collection.BufferUtils;
import hunt.collection.ByteBuffer;
import hunt.collection.List;

import hunt.io;
import hunt.Assert;
import hunt.Exceptions;
import hunt.concurrency.Promise;
import hunt.concurrency.CompletableFuture;
import hunt.text.Common;
import hunt.util.TypeUtils;

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

    this(HttpConfiguration config, TcpSession tcpSession,
            SecureSession secureSession, Http1ServerRequestHandler requestHandler,
            ServerSessionListener serverSessionListener, 
            WebSocketHandler webSocketHandler) {
        
        version (HUNT_DEBUG) 
            trace("initializing Http1ServerConnection ...");
        super(config, secureSession, tcpSession, requestHandler, null);
        requestHandler.connection = this;
        this.serverSessionListener = serverSessionListener;
        this.serverRequestHandler = requestHandler;
        this.webSocketHandler = webSocketHandler;
    }

    override protected HttpParser initHttpParser(HttpConfiguration config,
            RequestHandler requestHandler, ResponseHandler responseHandler) {
        return new HttpParser(requestHandler, config.getMaxRequestHeadLength());
    }

    override ConnectionType getConnectionType() {
        return super.getConnectionType();
    }

    override bool isEncrypted() {
        return super.isEncrypted();
    }

    HttpParser getParser() {
        return parser;
    }

    HttpConfiguration getHttp2Configuration() {
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

    override CompletableFuture!HttpTunnelConnection upgradeHttpTunnel() {
        auto c = new Completable!HttpTunnelConnection();
        // HttpTunnelConnection c = new HttpTunnelConnection();
        tunnelConnectionPromise = c;
        return c;
    }

    Http1ServerTunnelConnection createHttpTunnel() {
        if (tunnelConnectionPromise !is null) {
            Http1ServerTunnelConnection tunnelConnection = new Http1ServerTunnelConnection(secureSession,
                    tcpSession, httpVersion);
            tunnelConnectionPromise.succeeded(tunnelConnection);
            tcpSession.attachObject(tunnelConnection);
            return tunnelConnection;
        } else {
            return null;
        }
    }

    bool directUpgradeHttp2(HttpRequest request) {
        version (HUNT_DEBUG) info("Upgrading to Http2");

        if (HttpMethod.PRI.isSame(request.getMethod())) {
            Http2ServerConnection http2ServerConnection = new Http2ServerConnection(config,
                    tcpSession, secureSession, serverSessionListener);
            tcpSession.attachObject(http2ServerConnection);
            http2ServerConnection.getParser().directUpgrade();
            upgradeHttp2Complete = true;
            return true;
        } else {
            return false;
        }
    }

    bool upgradeProtocol(HttpRequest request, HttpResponse response,
            HttpOutputStream output, HttpConnection connection) {
        version (HUNT_DEBUG) warning("try upgrading protocol ...");                
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
                version (HUNT_DEBUG) {
                    tracef("the server received settings %s", TypeUtils.toHexString(settings));
                }

                SettingsFrame settingsFrame = SettingsBodyParser.parseBody(
                        BufferUtils.toBuffer(settings));
                if (settingsFrame is null) {
                    throw new BadMessageException("settings frame parsing error");
                } else {
                    responseH2c();

                    Http2ServerConnection http2ServerConnection = new Http2ServerConnection(config,
                            tcpSession, secureSession, serverSessionListener);
                    tcpSession.attachObject(http2ServerConnection);
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
                        secureSession, tcpSession,
                        null, webSocketHandler.getWebSocketPolicy(),
                        request, response, config);

                webSocketConnection.setNextIncomingFrames(new class IncomingFrames {

                    void incomingError(Exception t) {
                        webSocketHandler.onError(t, webSocketConnection);
                    }

                    void incomingFrame(Frame frame) {
                        webSocketHandler.onFrame(frame, webSocketConnection);
                    }
                });
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
                output.close();
                tcpSession.attachObject(webSocketConnection);
                upgradeWebSocketComplete = true;
                webSocketHandler.onConnect(webSocketConnection);
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
        httpGenerator = new HttpGenerator(true, true);
    }

    Http1ServerConnection getHttp1ServerConnection() {
        return connection;
    }

    void responseH2c() {
        getSession().encode(ByteBuffer.wrap(PredefinedHttp1Response.H2C_BYTES));
    }

    void response100Continue() {
        getSession().encode(ByteBuffer.wrap(PredefinedHttp1Response.CONTINUE_100_BYTES));
    }

    override protected void generateHttpMessageSuccessfully() {
        version (HUNT_DEBUG)
            tracef("server session %s generates the HTTP message completely",
                    connection.getSessionId());

        HttpResponse response = connection.getResponse();
        HttpRequest request = connection.getRequest();

        string requestConnectionValue = request.getFields().get(HttpHeader.CONNECTION);
        string responseConnectionValue = response.getFields().get(HttpHeader.CONNECTION);
        HttpVersion ver = request.getHttpVersion();

        if (ver == HttpVersion.HTTP_1_0) {
            if ("keep-alive".equalsIgnoreCase(requestConnectionValue)
                    && "keep-alive".equalsIgnoreCase(responseConnectionValue)) {
                tracef("the server %s connection %s is persistent",
                        response.getHttpVersion(), connection.getSessionId());
            } else {
                connection.close();
            }
        } else if (ver == HttpVersion.HTTP_1_1) { // the persistent connection is default in HTTP 1.1
            if ("close".equalsIgnoreCase(requestConnectionValue)
                    || "close".equalsIgnoreCase(responseConnectionValue)) {
                connection.close();
            } else {
                version (HUNT_DEBUG)
                    infof("the server %s connection %d is persistent",
                            response.getHttpVersion(), connection.getSessionId());
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
        return BufferUtils.allocate(connection.getHttp2Configuration().getMaxResponseHeadLength());
    }

    override protected ByteBuffer getTrailerByteBuffer() {
        return BufferUtils.allocate(connection.getHttp2Configuration()
                .getMaxResponseTrailerLength());
    }

    override protected TcpSession getSession() {
        return connection.getTcpSession();
    }

    override protected HttpGenerator getHttpGenerator() {
        return httpGenerator;
    }

}
