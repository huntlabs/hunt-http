module hunt.http.client.HttpClient;

import hunt.http.client.ClientHttp2SessionListener;
import hunt.http.client.HttpClientConnection;
import hunt.http.client.Http1ClientDecoder;
import hunt.http.client.HttpClientContext;
import hunt.http.client.Http2ClientDecoder;
import hunt.http.client.Http2ClientHandler;

import hunt.http.client.HttpClientResponse;
import hunt.http.client.HttpClientRequest;
import hunt.http.client.Call;
import hunt.http.client.RealCall;

import hunt.http.codec.CommonDecoder;
import hunt.http.codec.CommonEncoder;
import hunt.http.HttpOptions;
import hunt.http.codec.websocket.decode.WebSocketDecoder;
import hunt.http.util.Completable;

import hunt.Exceptions;
import hunt.concurrency.CompletableFuture;
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

// dfmt off
// version ( unittest ) {} 
// else {
//     shared static this() {
//         NetUtil.startEventLoop();
//     }

//     shared static ~this() {
//         NetUtil.stopEventLoop();
//     }
// }
// dfmt on

/**
*/
class HttpClient : AbstractLifecycle {

    // private string _host;
    // private int _port;
    // private NetClient client;
    private NetClientOptions clientOptions;
    private NetClient[int] _netClients;
    private HttpConfiguration httpConfiguration;

    this() {
        NetClientOptions clientOptions = new NetClientOptions();
        clientOptions.setIdleTimeout(60.seconds);
        clientOptions.setConnectTimeout(5.seconds);

        HttpConfiguration config = new HttpConfiguration(clientOptions);
        this(config);
    }

    this(HttpConfiguration c) {
        if (c is null) {
            throw new IllegalArgumentException("http configuration is null");
        }

        clientOptions = cast(NetClientOptions)c.getTcpConfiguration();
        if(clientOptions is null) {
            clientOptions = new NetClientOptions();
        }
        this.httpConfiguration = c;
         // = new ConcurrentHashMap!()();

        // CommonDecoder commonDecoder = new CommonDecoder(httpClientDecoder);

        // c.getTcpConfiguration().setDecoder(commonDecoder);
        // c.getTcpConfiguration().setEncoder(new CommonEncoder());
        // c.getTcpConfiguration().setHandler(new Http2ClientHandler(c, _netClients));

        start();
    }

    Completable!(HttpClientConnection) connect(string host, int port) {
        Completable!(HttpClientConnection) completable = new Completable!(HttpClientConnection)();
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

        client.connect(host, port);
    }

    HttpConfiguration getHttpConfiguration() {
        return httpConfiguration;
    }

    override protected void initialize() {
        // do nothing;
    }

    override protected void destroy() {
        // if (_netClients.length > 0) {
        //     _netClients
        // }
        _netClients = null;
    }

    /**
     * Prepares the {@code request} to be executed at some point in the future.
     */
    Call newCall(Request request) {
        return RealCall.newRealCall(this, request, false /* for web socket */);
    }    

}
