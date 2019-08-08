module hunt.http.server.HttpServer;

import hunt.http.server.Http1ServerDecoder;
import hunt.http.server.Http2ServerDecoder;
import hunt.http.server.HttpServerHandler;
import hunt.http.server.Http2ServerRequestHandler;
import hunt.http.server.ServerHttpHandler;
import hunt.http.server.ServerSessionListener;
import hunt.http.server.WebSocketHandler;

import hunt.http.codec.CommonDecoder;
import hunt.http.codec.CommonEncoder;
import hunt.http.HttpOptions;
import hunt.http.codec.websocket.decode.WebSocketDecoder;

import hunt.collection.BufferUtils;
import hunt.collection.ByteBuffer;
import hunt.event.EventLoop;
import hunt.util.DateTime;
import hunt.Exceptions;
import hunt.logging;
import hunt.net;
import hunt.util.Lifecycle;

import core.time;
import std.array;

/**
*/
class HttpServer : AbstractLifecycle {

    private NetServer _server;
    private NetServerOptions _serverOptions;
    private HttpServerHandler httpServerHandler;
    private HttpOptions _httpOptions;
    private string host;
    private int port;

    this(string host, int port, HttpOptions _httpOptions,
            ServerHttpHandler serverHttpHandler) {
        this(host, port, _httpOptions, new Http2ServerRequestHandler(serverHttpHandler),
                serverHttpHandler, new WebSocketHandler());
    }

    this(string host, int port, HttpOptions _httpOptions,
            ServerHttpHandler serverHttpHandler, WebSocketHandler webSocketHandler) {
        this(host, port, _httpOptions, new Http2ServerRequestHandler(serverHttpHandler),
                serverHttpHandler, webSocketHandler);
    }

    this(string host, int port, HttpOptions config, ServerSessionListener listener,
            ServerHttpHandler serverHttpHandler, WebSocketHandler webSocketHandler) {
        if (config is null)
            throw new IllegalArgumentException("the http2 configuration is null");

        if (host is null)
            throw new IllegalArgumentException("the http2 server host is empty");

        this.host = host;
        this.port = port;
        _serverOptions = cast(NetServerOptions)config.getTcpConfiguration();
        if(_serverOptions is null ) {
            _serverOptions = new NetServerOptions();
            config.setTcpConfiguration(_serverOptions);
        }
        this._httpOptions = config;
        
        httpServerHandler = new HttpServerHandler(config, listener,
                serverHttpHandler, webSocketHandler);

        version(WITH_HUNT_SECURITY) {
            import hunt.net.secure.SecureUtils;
            import std.file;
            import std.path;
            
            if (config.isSecureConnectionEnabled()) {
                string sslCertificate = config.sslCertificate();
                string sslPrivateKey = config.sslPrivateKey();
                if(sslCertificate.empty() || sslPrivateKey.empty()) {
                    warningf("No certificate files found. Using the defaults.");
                } else {
	                string currentRootPath = dirName(thisExePath);
                    sslCertificate = buildPath(currentRootPath, sslCertificate);
                    sslPrivateKey = buildPath(currentRootPath, sslPrivateKey);
                    if(!sslCertificate.exists() || !sslPrivateKey.exists()) {
                        warningf("No certificate files found. Using the defaults.");
                    } else {
                        SecureUtils.setServerCertificate(sslCertificate, sslPrivateKey, 
                            config.keystorePassword(), config.keyPassword());
                    }
                }
            }
        }

        _server = NetUtil.createNetServer!(ThreadMode.Single)(_serverOptions);

        _server.setCodec(new class Codec {
            private CommonEncoder encoder;
            private CommonDecoder decoder;

            this() {
                encoder = new CommonEncoder();

                Http1ServerDecoder httpServerDecoder = new Http1ServerDecoder(
                            new WebSocketDecoder(),
                            new Http2ServerDecoder());
                decoder = new CommonDecoder(httpServerDecoder);
            }

            Encoder getEncoder() {
                return encoder;
            }

            Decoder getDecoder() {
                return decoder;
            }
        });

        _server.setHandler(new HttpServerHandler(config, listener,
                serverHttpHandler, webSocketHandler));

        // string responseString = `HTTP/1.1 000 
        // Server: Hunt-HTTP/1.0
        // Date: Tue, 11 Dec 2018 08:17:36 GMT
        // Content-Type: text/plain
        // Content-Length: 13
        // Connection: keep-alive

        // Hello, World!`;


        version (HUNT_DEBUG) {
            if (config.isSecureConnectionEnabled())
                tracef("Listing at: https://%s:%d", host, port);
            else
                tracef("Listing at: http://%s:%d", host, port);
        }
    }

    HttpOptions getHttpOptions() {
        return _httpOptions;
    }

    string getHost() {
        return host;
    }

    int getPort() {
        return port;
    }

    // ExecutorService getNetExecutorService() {
    //     return _server.getNetExecutorService();
    // }

    override protected void initialize() {
        _server.listen(host, port);
    }

    override protected void destroy() {
        // if (_server !is null) {
        //     _server.stop();
        // }
    }

}
