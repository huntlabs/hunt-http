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

import hunt.container.ByteBuffer;
import hunt.container.Map;
import hunt.container.HashMap;

import hunt.net.AsynchronousTcpSession;
import hunt.net.Client;
import hunt.net;

import kiss.logger;

class HTTP2Client  : AbstractLifeCycle { 

    private Client client;
    private Map!(int, HTTP2ClientContext) http2ClientContext; // = new ConcurrentHashMap!()();
    private __gshared static int sessionId = 0; // new int(0);
    private HTTP2Configuration http2Configuration;

    this(HTTP2Configuration c) {
        if (c is null) {
            throw new IllegalArgumentException("the http2 configuration is null");
        }
        http2ClientContext = new HashMap!(int, HTTP2ClientContext)();

        HTTP1ClientDecoder httpClientDecoder = new HTTP1ClientDecoder(new HTTP2ClientDecoder());
        CommonDecoder commonDecoder = new CommonDecoder(httpClientDecoder);

        c.getTcpConfiguration().setDecoder(commonDecoder);
        c.getTcpConfiguration().setEncoder(new CommonEncoder());
        c.getTcpConfiguration().setHandler(new HTTP2ClientHandler(c, http2ClientContext));

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

    Completable!(HTTPClientConnection) connect(string host, int port) {
        Completable!(HTTPClientConnection) completable = new Completable!(HTTPClientConnection)();
        completable.id = "http2client";
        connect(host, port, completable);
        return completable;
    }

    void connect(string host, int port, Promise!(HTTPClientConnection) promise) {
        connect(host, port, promise, new ClientHTTP2SessionListener());
    }

    void connect(string host, int port, Promise!(HTTPClientConnection) promise, ClientHTTP2SessionListener listener) {
        _host = host;
        _port = port;        
        start();
        clientContext = new HTTP2ClientContext();
        clientContext.setPromise(promise);
        clientContext.setListener(listener);
        int id = sessionId++;
        version(HuntDebugMode) tracef("Client sessionId = %d", id);
        http2ClientContext.put(id, clientContext);
        client.connect(host, port, id);
    }

    HTTP2ClientContext clientContext;

    private string _host;
    private int _port;

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
