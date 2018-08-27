module hunt.http.server.http.HTTP1ServerConnection;

import hunt.http.server.http.HTTPServerConnection;
import hunt.http.server.http.HTTP1ServerRequestHandler;
import hunt.http.server.http.HTTP1ServerTunnelConnection;
import hunt.http.server.http.HTTP2ServerConnection;
import hunt.http.server.http.ServerSessionListener;
import hunt.http.server.http.WebSocketHandler;

import hunt.http.codec.http.decode.HttpParser;
import hunt.http.codec.http.decode.SettingsBodyParser;
import hunt.http.codec.http.encode.HttpGenerator;
import hunt.http.codec.http.encode.PredefinedHTTP1Response;

import hunt.http.codec.http.frame.HeadersFrame;
import hunt.http.codec.http.frame.PrefaceFrame;
import hunt.http.codec.http.frame.SettingsFrame;

import hunt.http.codec.http.model;
import hunt.http.codec.http.stream;

import hunt.net.ConnectionType;
import hunt.net.secure.SecureSession;
import hunt.net.Session;

import hunt.container.BufferUtils;
import hunt.container.ByteBuffer;
import hunt.container.List;

import hunt.util.Assert;
import hunt.util.exception;
import hunt.util.concurrent.Promise;
import hunt.util.concurrent.CompletableFuture;
import hunt.util.string;
import hunt.util.TypeUtils;

import hunt.logger;
import std.base64;


class HTTP1ServerConnection : AbstractHTTP1Connection , HTTPServerConnection {

    private  WebSocketHandler webSocketHandler;
    private  ServerSessionListener serverSessionListener;
    private  HTTP1ServerRequestHandler serverRequestHandler;
    private  bool upgradeHTTP2Complete = false; //new AtomicBoolean(false);
    private  bool upgradeWebSocketComplete = false; // new AtomicBoolean(false);
    // private  AtomicBoolean upgradeHTTP2Complete = new AtomicBoolean(false);
    // private  AtomicBoolean upgradeWebSocketComplete = new AtomicBoolean(false);
    // private HTTPTunnelConnection tunnelConnectionPromise;
    private Promise!HTTPTunnelConnection tunnelConnectionPromise;

    this(HTTP2Configuration config, TcpSession tcpSession, SecureSession secureSession,
                          HTTP1ServerRequestHandler requestHandler,
                          ServerSessionListener serverSessionListener,
                          WebSocketHandler webSocketHandler) {
        super(config, secureSession, tcpSession, requestHandler, null);
        requestHandler.connection = this;
        this.serverSessionListener = serverSessionListener;
        this.serverRequestHandler = requestHandler;
        this.webSocketHandler = webSocketHandler;
    }

    override
    protected HttpParser initHttpParser(HTTP2Configuration config, RequestHandler requestHandler, ResponseHandler responseHandler) {
        return new HttpParser(requestHandler, config.getMaxRequestHeadLength());
    }

    override
    ConnectionType getConnectionType() {
        return super.getConnectionType();
    }
        
    override
    bool isEncrypted() {
        return super.isEncrypted();
    }

    HttpParser getParser() {
        return parser;
    }

    HTTP2Configuration getHTTP2Configuration() {
        return config;
    }

    MetaData.Request getRequest() {
        return serverRequestHandler.request;
    }

    MetaData.Response getResponse() {
        return serverRequestHandler.response;
    }

    void response100Continue() {
        serverRequestHandler.outputStream.response100Continue();
    }

    private void responseH2c() {
        serverRequestHandler.outputStream.responseH2c();
    }

    override
    void upgradeHTTPTunnel(Promise!HTTPTunnelConnection tunnelConnectionPromise) {
        this.tunnelConnectionPromise = tunnelConnectionPromise;
    }

    override
    CompletableFuture!HTTPTunnelConnection upgradeHTTPTunnel() {
        auto c = new Completable!HTTPTunnelConnection();
        // HTTPTunnelConnection c = new HTTPTunnelConnection();
        tunnelConnectionPromise = c;
        return c;
    }

    HTTP1ServerTunnelConnection createHTTPTunnel() {
        if (tunnelConnectionPromise !is null) {
            HTTP1ServerTunnelConnection tunnelConnection = new HTTP1ServerTunnelConnection(secureSession, tcpSession, httpVersion);
            tunnelConnectionPromise.succeeded(tunnelConnection);
            tcpSession.attachObject(tunnelConnection);
            return tunnelConnection;
        } else {
            return null;
        }
    }

    static class HTTP1ServerResponseOutputStream : AbstractHTTP1OutputStream {

        private  HTTP1ServerConnection connection;
        private  HttpGenerator httpGenerator;

        this(MetaData.Response response, HTTP1ServerConnection connection) {
            super(response, false);
            this.connection = connection;
            httpGenerator = new HttpGenerator(true, true);
        }

        HTTP1ServerConnection getHTTP1ServerConnection() {
            return connection;
        }

        void responseH2c() {
            getSession().encode(ByteBuffer.wrap(PredefinedHTTP1Response.H2C_BYTES));
        }

        void response100Continue() {
            getSession().encode(ByteBuffer.wrap(PredefinedHTTP1Response.CONTINUE_100_BYTES));
        }

        override
        protected void generateHTTPMessageSuccessfully() {
            tracef("server session %s generates the HTTP message completely", connection.getSessionId());

             MetaData.Response response = connection.getResponse();
             MetaData.Request request = connection.getRequest();

            string requestConnectionValue = request.getFields().get(HttpHeader.CONNECTION);
            string responseConnectionValue = response.getFields().get(HttpHeader.CONNECTION);
            HttpVersion ver = request.getHttpVersion();

            // switch () {
                if(ver == HttpVersion.HTTP_1_0){
                    if ("keep-alive".equalsIgnoreCase(requestConnectionValue)
                            && "keep-alive".equalsIgnoreCase(responseConnectionValue)) {
                        tracef("the server %s connection %s is persistent", response.getHttpVersion(), connection.getSessionId());
                    } else {
                        connection.close();
                    }
                }
                else if(ver == HttpVersion.HTTP_1_1) { // the persistent connection is default in HTTP 1.1
                    if ("close".equalsIgnoreCase(requestConnectionValue)
                            || "close".equalsIgnoreCase(responseConnectionValue)) {
                        connection.close();
                    } else {
                        tracef("the server %s connection %s is persistent", response.getHttpVersion(),
                                connection.getSessionId());
                    }
                }
                else
                    throw new IllegalStateException("server response does not support the http version " ~ connection.getHttpVersion().toString());
            // }

        }

        override
        protected void generateHTTPMessageExceptionally(HttpGenerator.Result actualResult,
                                                        HttpGenerator.State actualState,
                                                        HttpGenerator.Result expectedResult,
                                                        HttpGenerator.State expectedState) {
            errorf("http1 generator error, actual: [%s, %s], expected: [%s, %s]", actualResult, actualState, expectedResult, expectedState);
            throw new IllegalStateException("server generates http message exception.");
        }

        override
        protected ByteBuffer getHeaderByteBuffer() {
            return BufferUtils.allocate(connection.getHTTP2Configuration().getMaxResponseHeadLength());
        }

        override
        protected ByteBuffer getTrailerByteBuffer() {
            return BufferUtils.allocate(connection.getHTTP2Configuration().getMaxResponseTrailerLength());
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

    bool directUpgradeHTTP2(MetaData.Request request) {
        if (HttpMethod.PRI.isSame(request.getMethod())) {
            HTTP2ServerConnection http2ServerConnection = new HTTP2ServerConnection(config, tcpSession, secureSession,
                    serverSessionListener);
            tcpSession.attachObject(http2ServerConnection);
            http2ServerConnection.getParser().directUpgrade();
            upgradeHTTP2Complete = true;
            return true;
        } else {
            return false;
        }
    }

    bool upgradeProtocol(MetaData.Request request, MetaData.Response response,
                            HTTPOutputStream output, HTTPConnection connection) {
        switch (ProtocolHelper.from(request)) {
            case Protocol.H2: {
                if (upgradeHTTP2Complete) {
                    throw new IllegalStateException("The connection has been upgraded HTTP2");
                }

                HttpField settingsField = request.getFields().getField(HttpHeader.HTTP2_SETTINGS);
                assert(settingsField !is null , "The http2 setting field must be not null.");

                // byte[] settings = Base64Utils.decodeFromUrlSafeString(settingsField.getValue());
                byte[] settings = cast(byte[])Base64.decode(settingsField.getValue());
                version(HuntDebugMode) {
                    tracef("the server received settings %s", TypeUtils.toHexString(settings));
                }

                SettingsFrame settingsFrame = SettingsBodyParser.parseBody(BufferUtils.toBuffer(settings));
                if (settingsFrame is null) {
                    throw new BadMessageException("settings frame parsing error");
                } else {
                    responseH2c();

                    HTTP2ServerConnection http2ServerConnection = new HTTP2ServerConnection(config,
                            tcpSession, secureSession, serverSessionListener);
                    tcpSession.attachObject(http2ServerConnection);
                    upgradeHTTP2Complete = true;
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
                implementationMissing();
                // if (upgradeWebSocketComplete) {
                //     throw new IllegalStateException("The connection has been upgraded WebSocket");
                // }

                // Assert.isTrue(HttpMethod.GET.isSame(request.getMethod()), "The method of the request MUST be GET in the websocket handshake.");
                // Assert.isTrue(request.getHttpVersion() == HttpVersion.HTTP_1_1, "The http version MUST be HTTP/1.1");

                // bool accept = webSocketHandler.acceptUpgrade(request, response, output, connection);
                // if (!accept) {
                //     return false;
                // }

                // string key = request.getFields().get("Sec-WebSocket-Key");
                // Assert.hasText(key, "Missing request header 'Sec-WebSocket-Key'");

                // WebSocketConnectionImpl webSocketConnection = new WebSocketConnectionImpl(
                //         secureSession, tcpSession,
                //         null, webSocketHandler.getWebSocketPolicy(),
                //         request, response, config);
                // webSocketConnection.setNextIncomingFrames(new IncomingFrames() {
                //     override
                //     void incomingError(Throwable t) {
                //         webSocketHandler.onError(t, webSocketConnection);
                //     }

                //     override
                //     void incomingFrame(Frame frame) {
                //         webSocketHandler.onFrame(frame, webSocketConnection);
                //     }
                // });
                // List<ExtensionConfig> negotiatedExtensions = webSocketConnection.getExtensionNegotiator().negotiate(request);

                // response.setStatus(HttpStatus.SWITCHING_PROTOCOLS_101);
                // response.getFields().put(HttpHeader.UPGRADE, "WebSocket");
                // response.getFields().add(HttpHeader.CONNECTION.asString(), "Upgrade");
                // response.getFields().add(HttpHeader.SEC_WEBSOCKET_ACCEPT.asString(), AcceptHash.hashKey(key));
                // if (!CollectionUtils.isEmpty(negotiatedExtensions)) {
                //     negotiatedExtensions.stream().filter(e -> e.getName().equals("permessage-deflate"))
                //                         .findFirst().ifPresent(e -> e.getParameters().clear());
                //     response.getFields().add(HttpHeader.SEC_WEBSOCKET_EXTENSIONS.asString(), ExtensionConfig.toHeaderValue(negotiatedExtensions));
                // }

                // IO.close(output);
                // tcpSession.attachObject(webSocketConnection);
                // upgradeWebSocketComplete.compareAndSet(false, true);
                // webSocketHandler.onConnect(webSocketConnection);
                return true;
            }
            default:
                return false;
        }
    }

    bool getUpgradeHTTP2Complete() {
        return upgradeHTTP2Complete;
    }

    bool getUpgradeWebSocketComplete() {
        return upgradeWebSocketComplete;
    }

    Promise!HTTPTunnelConnection getTunnelConnectionPromise() {
        return tunnelConnectionPromise;
    }
}
