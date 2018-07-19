module hunt.http.client.http.HTTP2Client;

import hunt.http.client.http.ClientHTTP2SessionListener;
import hunt.http.client.http.HTTPClientConnection;
import hunt.http.client.http.HTTP1ClientDecoder;
import hunt.http.client.http.HTTP2ClientContext;
import hunt.http.client.http.HTTP2ClientDecoder;
import hunt.http.client.http.HTTP2ClientHandler;

import hunt.http.codec.common.CommonDecoder;
import hunt.http.codec.common.CommonEncoder;
import hunt.http.codec.http.stream.HTTP2Configuration;
import hunt.http.codec.websocket.decode.WebSocketDecoder;

import hunt.util.LifeCycle;
import hunt.util.exception;
import hunt.util.concurrent.CompletableFuture;;
import hunt.util.concurrent.Promise;

import hunt.container.Map;
import hunt.container.HashMap;

import hunt.net.Client;
import hunt.net;

class HTTP2Client  : AbstractLifeCycle { 

    private Client client;
    private Map!(int, HTTP2ClientContext) http2ClientContext; // = new ConcurrentHashMap!()();
    private int sessionId = 0; // new int(0);
    private HTTP2Configuration http2Configuration;

    this(HTTP2Configuration c) {
        if (c is null) {
            throw new IllegalArgumentException("the http2 configuration is null");
        }
        http2ClientContext = new HashMap!(int, HTTP2ClientContext)();

        c.getTcpConfiguration().setDecoder(new CommonDecoder(new HTTP1ClientDecoder(new HTTP2ClientDecoder())));
        c.getTcpConfiguration().setEncoder(new CommonEncoder());
        c.getTcpConfiguration().setHandler(new HTTP2ClientHandler(c, http2ClientContext));
        

        // TODO: Tasks pending completion -@Administrator at 2018-7-13 15:33:24
        // 

        this.client = Net.createNetClient();
        // this.client = new AsynchronousTcpClient(c.getTcpConfiguration());
        client.setConfig(c.getTcpConfiguration());
        
        this.http2Configuration = c;
    }

    Completable!(HTTPClientConnection) connect(string host, int port) {
        Completable!(HTTPClientConnection) completable = new Completable!(HTTPClientConnection)();
        connect(host, port, completable);
        return completable;
    }

    void connect(string host, int port, Promise!(HTTPClientConnection) promise) {
        connect(host, port, promise, new ClientHTTP2SessionListener());
    }

    void connect(string host, int port, Promise!(HTTPClientConnection) promise, ClientHTTP2SessionListener listener) {
        start();
        HTTP2ClientContext context = new HTTP2ClientContext();
        context.setPromise(promise);
        context.setListener(listener);
        int id = sessionId++;
        http2ClientContext.put(0, context);
        client.connect(host, port);
    }

    HTTP2Configuration getHttp2Configuration() {
        return http2Configuration;
    }

    override
    protected void init() {
    }

    override
    protected void destroy() {
        if (client !is null) {
            client.stop();
        }
    }

}
