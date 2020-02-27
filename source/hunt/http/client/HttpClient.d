module hunt.http.client.HttpClient;

import hunt.http.client.ClientHttp2SessionListener;
import hunt.http.client.HttpClientConnection;
import hunt.http.client.Http1ClientDecoder;
import hunt.http.client.HttpClientContext;
import hunt.http.client.Http2ClientDecoder;
import hunt.http.client.Http2ClientHandler;
import hunt.http.HttpOptions;
import hunt.http.client.HttpClientOptions;
import hunt.http.client.HttpClientResponse;
import hunt.http.client.HttpClientRequest;
import hunt.http.client.Call;
import hunt.http.client.RealCall;

import hunt.http.codec.CommonDecoder;
import hunt.http.codec.CommonEncoder;
import hunt.http.codec.websocket.decode.WebSocketDecoder;
// import hunt.http.util.Completable;

import hunt.Exceptions;
import hunt.concurrency.Future;
import hunt.concurrency.FuturePromise;
import hunt.concurrency.Promise;

import hunt.collection.BufferUtils;
import hunt.collection.ByteBuffer;
import hunt.collection.Map;
import hunt.collection.HashMap;

import hunt.logging.ConsoleLogger;
import hunt.net;
import hunt.util.Lifecycle;

import core.atomic;
import core.time;

/**
*/
class HttpClient : AbstractLifecycle {

    alias void delegate() Callback;

    private NetClientOptions clientOptions;
    private NetClient[int] _netClients;
    private HttpClientOptions httpConfiguration;
    private Callback _onClosed = null;
    private bool _isConnected = false;

    this() {
        NetClientOptions clientOptions = new NetClientOptions();
        clientOptions.setIdleTimeout(15.seconds);
        clientOptions.setConnectTimeout(5.seconds);
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
            c.setTcpConfiguration(clientOptions);
        }
        this.httpConfiguration = c;
         // = new ConcurrentHashMap!()();

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
        }).setHandler(new Http2ClientHandler(httpConfiguration, clientContext));

        client.setOnClosed(_onClosed);
        client.connect(host, port);
        _isConnected = client.isConnected();
    }

    HttpClientOptions getHttpConfiguration() {
        return httpConfiguration;
    }

    void close() {
        stop();
    }

    void setOnClosed(Callback callback)
    {
        _onClosed = callback;
    }

    override protected void initialize() {
        // do nothing;
    }

    override  void destroy() {
        foreach(NetClient client; _netClients) {
            client.close();
        }
        
        _netClients = null;
    }

    bool isConnected() {
        return _isConnected;
    }

   /**
     * Prepares the {@code request} to be executed at some point in the future.
     */
    Call newCall(Request request) {
        return RealCall.newRealCall(this, request, false /* for web socket */);
    }    

}
