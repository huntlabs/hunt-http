module hunt.http.client.HttpClient;

import hunt.http.client.ClientHttp2SessionListener;
import hunt.http.client.HttpClientConnection;
import hunt.http.client.Http1ClientDecoder;
import hunt.http.client.Http2ClientContext;
import hunt.http.client.Http2ClientDecoder;
import hunt.http.client.Http2ClientHandler;

import hunt.http.codec.common.CommonDecoder;
import hunt.http.codec.common.CommonEncoder;
import hunt.http.codec.http.stream.Http2Configuration;
import hunt.http.codec.websocket.decode.WebSocketDecoder;

import hunt.util.LifeCycle;
import hunt.util.exception;
import hunt.util.concurrent.CompletableFuture;;
import hunt.util.concurrent.Promise;

import hunt.container.ByteBuffer;
import hunt.container.Map;
import hunt.container.HashMap;

import hunt.net.AsynchronousTcpSession;
import hunt.net.Client;
import hunt.net;

import hunt.logging;

class HttpClient  : AbstractLifeCycle { 

    private Client client;
    private Map!(int, Http2ClientContext) http2ClientContext; // = new ConcurrentHashMap!()();
    private __gshared static int sessionId = 0; // new int(0);
    private Http2Configuration http2Configuration;

    this(Http2Configuration c) {
        if (c is null) {
            throw new IllegalArgumentException("the http2 configuration is null");
        }
        http2ClientContext = new HashMap!(int, Http2ClientContext)();

        Http1ClientDecoder httpClientDecoder = new Http1ClientDecoder(new WebSocketDecoder(), new Http2ClientDecoder());
        CommonDecoder commonDecoder = new CommonDecoder(httpClientDecoder);

        c.getTcpConfiguration().setDecoder(commonDecoder);
        c.getTcpConfiguration().setEncoder(new CommonEncoder());
        c.getTcpConfiguration().setHandler(new Http2ClientHandler(c, http2ClientContext));

        NetClient client = Net.createNetClient();
        this.client = client;
        // this.client = new AsynchronousTcpClient(c.getTcpConfiguration());
        client.setConfig(c.getTcpConfiguration());

        client.connectHandler((NetSocket sock){
            infof("A connection created with %s:%d", _host, _port);
            AsynchronousTcpSession session = cast(AsynchronousTcpSession)sock;

            session.handler( (const ubyte[] data) {    
                infof("data received (%d bytes): ", data.length);                 
                version(HuntDebugMode) {
                    if(data.length<=64)
                        infof("%(%02X %)", data[0 .. $]);
                    else
                    {
                        infof("%(%02X %) ...", data[0 .. 64]);
                        // debug { infof("%(%02X %)", data[0 .. $]); }
                        // else{ infof("%(%02X %) ...", data[0 .. 64]);  }
                    }
                }

                ByteBuffer buf = ByteBuffer.wrap(cast(byte[])data);
                commonDecoder.decode(buf, session);
                // httpClientDecoder.decode(buf, session);
                }
            );
        });

        this.http2Configuration = c;
    }

    Completable!(HttpClientConnection) connect(string host, int port) {
        Completable!(HttpClientConnection) completable = new Completable!(HttpClientConnection)();
        completable.id = "http2client";
        connect(host, port, completable);
        return completable;
    }

    void connect(string host, int port, Promise!(HttpClientConnection) promise) {
        connect(host, port, promise, new ClientHttp2SessionListener());
    }

    void connect(string host, int port, Promise!(HttpClientConnection) promise, ClientHttp2SessionListener listener) {
        _host = host;
        _port = port;        
        start();
        clientContext = new Http2ClientContext();
        clientContext.setPromise(promise);
        clientContext.setListener(listener);
        int id = sessionId++;
        version(HuntDebugMode) tracef("Client sessionId = %d", id);
        http2ClientContext.put(id, clientContext);
        client.connect(host, port, id);
    }

    Http2ClientContext clientContext;

    private string _host;
    private int _port;

    Http2Configuration getHttp2Configuration() {
        return http2Configuration;
    }

    override
    protected void initilize() {
    }

    override
    protected void destroy() {
        if (client !is null) {
            client.stop();
        }
    }

}
