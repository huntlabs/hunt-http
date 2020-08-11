module hunt.http.client.HttpClient;

import hunt.http.client.Call;
import hunt.http.client.ClientHttp2SessionListener;
import hunt.http.client.ClientHttpHandler;
import hunt.http.client.CookieStore;
import hunt.http.client.HttpClientConnection;
import hunt.http.client.HttpClientHandler;
import hunt.http.client.Http1ClientDecoder;
import hunt.http.client.HttpClientContext;
import hunt.http.client.Http2ClientDecoder;
import hunt.http.client.HttpClientOptions;
import hunt.http.client.HttpClientResponse;
import hunt.http.client.HttpClientRequest;
import hunt.http.client.InMemoryCookieStore;
import hunt.http.client.RealCall;

import hunt.http.codec.CommonDecoder;
import hunt.http.codec.CommonEncoder;
import hunt.http.codec.websocket.decode.WebSocketDecoder;
import hunt.http.codec.websocket.frame.DataFrame;

import hunt.http.HttpBody;
import hunt.http.HttpConnection;
import hunt.http.HttpOptions;
import hunt.http.HttpOutputStream;
import hunt.http.HttpRequest;
import hunt.http.HttpResponse;
import hunt.http.WebSocketConnection;
import hunt.http.WebSocketFrame;
import hunt.http.WebSocketPolicy;

import hunt.Exceptions;
import hunt.concurrency.Future;
import hunt.concurrency.FuturePromise;
import hunt.concurrency.Promise;

import hunt.io.BufferUtils;
import hunt.io.ByteBuffer;
import hunt.collection.Map;
import hunt.collection.HashMap;

import hunt.logging.ConsoleLogger;
import hunt.net;
import hunt.util.AbstractLifecycle;

import core.atomic;
import core.time;

/**
 * 
 */
class HttpClient : AbstractLifecycle {

    enum Duration DEFAULT_IDLE_TIMEOUT = 15.seconds;
    enum Duration DEFAULT_CONNECT_TIMEOUT = 10.seconds;

    alias Callback = void delegate();

    private NetClientOptions clientOptions;
    private NetClient[int] _netClients;
    private HttpClientOptions _httpOptions;
    private Callback _onClosed = null;
    private CookieStore _cookieStore;

    this() {
        clientOptions = new NetClientOptions();
        clientOptions.setIdleTimeout(DEFAULT_IDLE_TIMEOUT);
        clientOptions.setConnectTimeout(DEFAULT_CONNECT_TIMEOUT);
        HttpClientOptions config = new HttpClientOptions(clientOptions);
        this(config);
    }

    this(HttpClientOptions c) {
        if (c is null) {
            throw new IllegalArgumentException("http configuration is null");
        }

        clientOptions = c.getTcpConfiguration();
        if(clientOptions is null) {
            clientOptions = new NetClientOptions();
            clientOptions.setIdleTimeout(DEFAULT_IDLE_TIMEOUT);
            clientOptions.setConnectTimeout(DEFAULT_CONNECT_TIMEOUT);
            c.setTcpConfiguration(clientOptions);
        } else {
            if(clientOptions.getIdleTimeout == Duration.zero) 
                clientOptions.setIdleTimeout(DEFAULT_IDLE_TIMEOUT);

            if(clientOptions.getConnectTimeout == Duration.zero)
                clientOptions.setConnectTimeout(DEFAULT_CONNECT_TIMEOUT);
        }

        this._httpOptions = c;

        start();
    }

    Future!(HttpClientConnection) connect(string host, int port) {
        FuturePromise!(HttpClientConnection) completable = new FuturePromise!(HttpClientConnection)();
        completable.id = "httpclient";
        connect(host, port, completable);
        return completable;
    }

    void connect(string host, int port, Promise!(HttpClientConnection) promise) {
        connect(host, port, promise, new ClientHttp2SessionListener());
    }

    void connect(string host, int port, Promise!(HttpClientConnection) promise,
            ClientHttp2SessionListener listener) {

        HttpClientContext clientContext = new HttpClientContext();
        clientContext.setPromise(promise);
        clientContext.setListener(listener);

        NetClient client = NetUtil.createNetClient(clientOptions);
        int clientId = client.getId();
        if(clientId in _netClients) {
            warningf("clientId existes: %d", clientId);
        }
        _netClients[client.getId()] = client;
        
        client.setCodec(new class Codec {

            private CommonEncoder encoder;
            private CommonDecoder decoder;

            this() {
                encoder = new CommonEncoder();

                Http1ClientDecoder httpClientDecoder = new Http1ClientDecoder(
                            new WebSocketDecoder(),
                            new Http2ClientDecoder());
                decoder = new CommonDecoder(httpClientDecoder);
            }

            Encoder getEncoder() {
                return encoder;
            }

            Decoder getDecoder() {
                return decoder;
            }
        })
        .setHandler(new HttpClientHandler(_httpOptions, clientContext));

        client.onClosed(_onClosed);
        client.connect(host, port);
        // _isConnected = client.isConnected();
    }

    HttpClientOptions getHttpOptions() {
        return _httpOptions;
    }

    void close() {
        stop();
    }

    void setOnClosed(Callback callback) {
        _onClosed = callback;
    }

    override protected void initialize() {
        // do nothing
    }

    override void destroy() {
        foreach(NetClient client; _netClients) {
            client.close();
        }
        
        _netClients = null;
    }

    deprecated("Unsupported anymore!")
    bool isConnected() {
        // return _isConnected;
        return false;
    }

    /**
     * Sets the handler that can accept cookies from incoming HTTP responses and provides cookies to
     * outgoing HTTP requests.
     *
     * <p>If unset, {@linkplain CookieStore#NO_COOKIES no cookies} will be accepted nor provided.
     */
    HttpClient useCookieStore() {
        _cookieStore = new InMemoryCookieStore();
        return this;
    }
    
    /** 
     * 
     * Params:
     *   store = 
     * Returns: 
     */
    HttpClient useCookieStore(CookieStore store) {
        if (store is null) throw new NullPointerException("CookieStore is null");
        _cookieStore = store;
        return this;
    }

    CookieStore getCookieStore() {
        return _cookieStore;
    }

    /**
     * Prepares the {@code request} to be executed at some point in the future.
     */
    Call newCall(Request request) {
        return RealCall.newRealCall(this, request, false /* for web socket */);
    }    

    /**
     * Uses {@code request} to connect a new web socket.
     */
    WebSocketConnection newWebSocket(Request request, WebSocketMessageHandler handler) {
        assert(handler !is null);
        
// import core.atomic;
// import core.sync.condition;
// import core.sync.mutex;

// 		Mutex responseLocker = new Mutex();
// 		Condition responseCondition = new Condition(responseLocker);
        
        HttpURI uri = request.getURI();
        string scheme = uri.getScheme();
        string host = uri.getHost();
        int port = uri.getPort();
        
        
        // responseLocker.lock();
        // scope(exit) {
        //     responseLocker.unlock();
        // }
        
        Future!(HttpClientConnection) conn = connect(host, port);
        
        TcpSslOptions tcpOptions = _httpOptions.getTcpConfiguration(); 
        Duration idleTimeout = tcpOptions.getIdleTimeout();   
        
        HttpClientConnection connection = conn.get();
        assert(connection !is null);
        
        FuturePromise!WebSocketConnection promise = new FuturePromise!WebSocketConnection();
        WebSocketConnection webSocket;

        AbstractClientHttpHandler httpHandler = new class AbstractClientHttpHandler {
            override bool messageComplete(HttpRequest request,
                    HttpResponse response, HttpOutputStream output, HttpConnection connection) {
                version(HUNT_HTTP_DEBUG) tracef("Upgrade to WebSocket successfully: " ~ response.toString());
                return true;
            }
        };

        IncomingFrames incomingFrames = new class IncomingFrames {
            void incomingError(Exception ex) {
                version(HUNT_DEBUG) warningf(ex.msg);
                handler.onError(webSocket, ex);
            }

            void incomingFrame(WebSocketFrame frame) {
                WebSocketFrameType type = frame.getType();
                version(HUNT_HTTP_DEBUG) tracef("new frame comming: %s", type);
                switch (type) {
                    case WebSocketFrameType.TEXT:
                        handler.onText(webSocket, (cast(DataFrame) frame).getPayloadAsUTF8());
                        break;
                        
                    case WebSocketFrameType.BINARY:
                        handler.onBinary(webSocket, frame.getPayload());
                        break;
                        
                    case WebSocketFrameType.CLOSE:
                        handler.onClosed(webSocket);
                        break;

                    case WebSocketFrameType.PING:
                        handler.onPing(webSocket);
                        break;

                    case WebSocketFrameType.PONG:
                        handler.onPong(webSocket);
                        break;

                    case WebSocketFrameType.CONTINUATION:
                        handler.onContinuation(webSocket, frame.getPayload());
                        break;

                    default:
                        warningf("Can't handle the frame of ", type);
                        break;
                }
            }
        };

        connection.upgradeWebSocket(request, WebSocketPolicy.newClientPolicy(),
                promise, httpHandler, incomingFrames);

        if(idleTimeout.isNegative()) {
            version (HUNT_HTTP_DEBUG) infof("waitting for response...");
            webSocket =  promise.get();
            handler.onOpen(webSocket);
        } else {
            version (HUNT_HTTP_DEBUG) infof("waitting for response in %s ...", idleTimeout);
            try {
                webSocket = promise.get(idleTimeout);
                handler.onOpen(webSocket);
            } catch(Exception ex ) {
                version(HUNT_HTTP_DEBUG) warningf(ex.msg);
                handler.onError(webSocket, ex);
            }
        }
        return webSocket;
    }

}
