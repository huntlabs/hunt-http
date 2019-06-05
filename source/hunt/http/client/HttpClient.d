module hunt.http.client.HttpClient;

import hunt.http.client.ClientHttp2SessionListener;
import hunt.http.client.HttpClientConnection;
import hunt.http.client.Http1ClientDecoder;
import hunt.http.client.Http2ClientContext;
import hunt.http.client.Http2ClientDecoder;
import hunt.http.client.Http2ClientHandler;

import hunt.http.client.HttpClientResponse;
import hunt.http.client.HttpClientRequest;
import hunt.http.client.Call;
import hunt.http.client.RealCall;

import hunt.http.codec.CommonDecoder;
import hunt.http.codec.CommonEncoder;
import hunt.http.codec.http.stream.HttpConfiguration;
import hunt.http.codec.websocket.decode.WebSocketDecoder;
import hunt.http.util.Completable;

import hunt.Exceptions;
import hunt.concurrency.CompletableFuture;
import hunt.concurrency.Promise;

import hunt.collection.ByteBuffer;
import hunt.collection.Map;
import hunt.collection.HashMap;

import hunt.logging;
import hunt.net.AsynchronousTcpSession;
import hunt.net.Client;
import hunt.net;
import hunt.util.Lifecycle;

import core.atomic;
import hunt.collection.BufferUtils;

shared static this() {
    NetUtil.startEventLoop();
}

shared static ~this() {
    NetUtil.stopEventLoop();
}


/**
*/
class HttpClient : AbstractLifecycle {

    private string _host;
    private int _port;
    private AbstractClient client;
    private Map!(int, Http2ClientContext) http2ClientContext;
    private static shared int sessionId = 0;
    private HttpConfiguration httpConfiguration;

    this() {
        HttpConfiguration config = new HttpConfiguration();
        config.getTcpConfiguration().setTimeout(60 * 1000);
        this(config);
    }

    this(HttpConfiguration c) {
        if (c is null) {
            throw new IllegalArgumentException("http configuration is null");
        }
        http2ClientContext = new HashMap!(int, Http2ClientContext)();
         // = new ConcurrentHashMap!()();

        // http2ClientContext.put(111, null);

        Http1ClientDecoder httpClientDecoder = new Http1ClientDecoder(new WebSocketDecoder(),
                new Http2ClientDecoder());
        CommonDecoder commonDecoder = new CommonDecoder(httpClientDecoder);

        c.getTcpConfiguration().setDecoder(commonDecoder);
        c.getTcpConfiguration().setEncoder(new CommonEncoder());
        c.getTcpConfiguration().setHandler(new Http2ClientHandler(c, http2ClientContext));

        NetClient client = NetUtil.createNetClient();
        this.client = client;
        // this.client = new AsynchronousTcpClient(c.getTcpConfiguration());
        client.setConfig(c.getTcpConfiguration());

        client.connectHandler((NetSocket sock) {
            version (HUNT_DEBUG) infof("A connection created with %s:%d", _host, _port);
            AsynchronousTcpSession session = cast(AsynchronousTcpSession) sock;

            session.handler((ByteBuffer buffer) {
                version (HUNT_HTTP_DEBUG_MORE) {
                    byte[] data = buffer.getRemaining();
                    infof("data received (%d bytes): ", data.length);
                    if (data.length <= 64) {
                        infof("%(%02X %)", data[0 .. $]);
                    } else {
                        infof("%(%02X %) ...", data[0 .. 64]);
                    }
                }

                commonDecoder.decode(buffer, session);
            });
        });

        this.httpConfiguration = c;
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
        _host = host;
        _port = port;
        start();
        clientContext = new Http2ClientContext();
        clientContext.setPromise(promise);
        clientContext.setListener(listener);

        int id = atomicOp!("+=")(sessionId, 1);
        version (HUNT_DEBUG)
            tracef("Client sessionId = %d", id);
        http2ClientContext.put(id, clientContext);
        client.connect(host, port, id);
    }

    Http2ClientContext clientContext;

    HttpConfiguration getHttpConfiguration() {
        return httpConfiguration;
    }

    override protected void initialize() {
    }

    override protected void destroy() {
        if (client !is null) {
            client.stop();
        }
    }

    /**
     * Prepares the {@code request} to be executed at some point in the future.
     */
    Call newCall(Request request) {
        return RealCall.newRealCall(this, request, false /* for web socket */);
    }    

}
