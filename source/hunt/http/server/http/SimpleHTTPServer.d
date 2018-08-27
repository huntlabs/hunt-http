module hunt.http.server.http.SimpleHTTPServer;

import hunt.http.server.http.HTTP2Server;
import hunt.http.server.http.HTTPServerConnection;
import hunt.http.server.http.ServerHTTPHandler;
import hunt.http.server.http.SimpleHTTPServerConfiguration;
import hunt.http.server.http.SimpleRequest;
import hunt.http.server.http.WebSocketHandler;

import hunt.http.codec.http.model.HttpStatus;
import hunt.http.codec.http.model.MetaData;

import hunt.http.codec.http.stream.HTTPConnection;
import hunt.http.codec.http.stream.HTTPOutputStream;

// import hunt.http.codec.websocket.frame.Frame;
// import hunt.http.codec.websocket.stream.WebSocketConnection;
import hunt.http.codec.websocket.stream.WebSocketPolicy;

import hunt.logger;

import hunt.util.Charset;
import hunt.util.exception;
import hunt.util.functional;
import hunt.io;
import hunt.util.LifeCycle;

import hunt.container.HashMap;
import hunt.container.Map;

/**
*/
class SimpleHTTPServer : AbstractLifeCycle { 

    private static  int defaultPoolSize = 10; // int.getInteger("hunt.http.server.http.async.defaultPoolSize", Runtime.getRuntime().availableProcessors());

    private HTTP2Server http2Server;
    private SimpleHTTPServerConfiguration configuration;

    private Action1!SimpleRequest _headerComplete;
    private Action3!(int, string, SimpleRequest) _badMessage;
    private Action1!SimpleRequest _earlyEof;
    private Action1!HTTPConnection _acceptConnection;
    private Action2!(SimpleRequest, HTTPServerConnection) tunnel;

    // private Meter requestMeter;
    // private ExecutorService handlerExecutorService;

    private Map!(string, WebSocketHandler) webSocketHandlerMap = new HashMap!(string, WebSocketHandler)();
    private WebSocketPolicy _webSocketPolicy;

    this() {
        this(new SimpleHTTPServerConfiguration());
    }

    this(SimpleHTTPServerConfiguration configuration) {
        this.configuration = configuration;
        // TODO: Tasks pending completion -@zxp at 7/5/2018, 2:59:11 PM
        // 
        // requestMeter = this.configuration.getTcpConfiguration()
        //                                  .getMetricReporterFactory()
        //                                  .getMetricRegistry()
        //                                  .meter("http2.SimpleHTTPServer.request.count");
        // handlerExecutorService = new ForkJoinPool(defaultPoolSize, (pool) {
        //     ForkJoinWorkerThread workerThread = ForkJoinPool.defaultForkJoinWorkerThreadFactory.newThread(pool);
        //     workerThread.setName("hunt-http-server-handler-pool-" ~ workerThread.getPoolIndex());
        //     return workerThread;
        // }, null, true);
    }

    SimpleHTTPServer acceptHTTPTunnelConnection(Action2!(SimpleRequest, HTTPServerConnection) tunnel) {
        this.tunnel = tunnel;
        return this;
    }

    SimpleHTTPServer headerComplete(Action1!SimpleRequest h) {
        this._headerComplete = h;
        return this;
    }

    SimpleHTTPServer earlyEof(Action1!SimpleRequest e) {
        this._earlyEof = e;
        return this;
    }

    SimpleHTTPServer badMessage(Action3!(int, string, SimpleRequest) b) {
        this._badMessage = b;
        return this;
    }

    SimpleHTTPServer acceptConnection(Action1!HTTPConnection a) {
        this._acceptConnection = a;
        return this;
    }

    SimpleHTTPServer registerWebSocket(string uri, WebSocketHandler webSocketHandler) {
        webSocketHandlerMap.put(uri, webSocketHandler);
        return this;
    }

    SimpleHTTPServer webSocketPolicy(WebSocketPolicy w) {
        this._webSocketPolicy = w;
        return this;
    }

    // ExecutorService getNetExecutorService() {
    //     return http2Server.getNetExecutorService();
    // }

    // ExecutorService getHandlerExecutorService() {
    //     return handlerExecutorService;
    // }

    SimpleHTTPServerConfiguration getConfiguration() {
        return configuration;
    }

    void listen(string host, int port) {
        configuration.setHost(host);
        configuration.setPort(port);
        listen();
    }

    void listen() {
        start();
    }

    override
    protected void init() {

        // class SimpleWebSocketHandler : WebSocketHandler
        // {
        //     override
        //     bool acceptUpgrade(MetaData.Request request, MetaData.Response response,
        //                                  HTTPOutputStream output,
        //                                  HTTPConnection connection) {
        //         info("The connection %s will upgrade to WebSocket connection", connection.getSessionId());
        //         WebSocketHandler handler = webSocketHandlerMap.get(request.getURI().getPath());
        //         if (handler == null) {
        //             response.setStatus(HttpStatus.BAD_REQUEST_400);
        //             try (HTTPOutputStream ot = output) {
        //                 ot.write(("The " ~ request.getURI().getPath() ~ " can not upgrade to WebSocket").getBytes(StandardCharsets.UTF_8));
        //             } catch (IOException e) {
        //                 errorf("Write http message exception", e);
        //             }
        //             return false;
        //         } else {
        //             return handler.acceptUpgrade(request, response, output, connection);
        //         }
        //     }

        //     override
        //     void onConnect(WebSocketConnection webSocketConnection) {
        //         Optional.ofNullable(webSocketHandlerMap.get(webSocketConnection.getUpgradeRequest().getURI().getPath()))
        //                 .ifPresent(handler -> handler.onConnect(webSocketConnection));
        //     }

        //     override
        //     WebSocketPolicy getWebSocketPolicy() {
        //         if (_webSocketPolicy != null) {
        //             return _webSocketPolicy;
        //         } else {
        //             return defaultWebSocketPolicy;
        //         }
        //     }

        //     override
        //     void onFrame(Frame frame, WebSocketConnection connection) {
        //         Optional.ofNullable(webSocketHandlerMap.get(connection.getUpgradeRequest().getURI().getPath()))
        //                 .ifPresent(handler -> handler.onFrame(frame, connection));
        //     }

        //     override
        //     void onError(Throwable t, WebSocketConnection connection) {
        //         Optional.ofNullable(webSocketHandlerMap.get(connection.getUpgradeRequest().getURI().getPath()))
        //                 .ifPresent(handler -> handler.onError(t, connection));
        //     }
        // }

        http2Server = new HTTP2Server(configuration.getHost(), configuration.getPort(), configuration, 
            new ServerHTTPHandlerAdapter().acceptConnection(_acceptConnection).acceptHTTPTunnelConnection((request, 
                response, ot, connection) {
            SimpleRequest r = new SimpleRequest(request, response, ot, cast(HTTPConnection)connection);
            request.setAttachment(r);
            if (tunnel !is null) {
                tunnel(r, connection);
            }
            return true;
        }).headerComplete((request, response, ot, connection) {
            SimpleRequest r = new SimpleRequest(request, response, ot, connection);
            request.setAttachment(r);
            if (_headerComplete != null) {
                _headerComplete(r);
            }
            // requestMeter.mark();
            return false;
        }).content((buffer, request, response, ot, connection) {
            SimpleRequest r = cast(SimpleRequest) request.getAttachment();
            if (r.content !is null) {
                r.content(buffer);
            } else {
                r.requestBody.add(buffer);
            }
            return false;
        }).contentComplete((request, response, ot, connection)  {
            SimpleRequest r = cast(SimpleRequest) request.getAttachment();
            if (r.contentComplete !is null) {
                r.contentComplete(r);
            }
            return false;
        }).messageComplete((request, response, ot, connection)  {
            SimpleRequest r = cast(SimpleRequest) request.getAttachment();
            if (r.messageComplete != null) {
                r.messageComplete(r);
            }
            if (!r.getResponse().isAsynchronous()) {
                IO.close(r.getResponse());
            }
            return true;
        }).badMessage((status, reason, request, response, ot, connection)  {
            if (_badMessage !is null) {
                if (request.getAttachment() !is null) {
                    SimpleRequest r = cast(SimpleRequest) request.getAttachment();
                    _badMessage(status, reason, r);
                } else {
                    SimpleRequest r = new SimpleRequest(request, response, ot, connection);
                    request.setAttachment(r);
                    _badMessage(status, reason, r);
                }
            }
        }).earlyEOF(delegate void (request, response, ot, connection)  {
            if (_earlyEof != null) {
                if (request.getAttachment() !is null) {
                    SimpleRequest r = cast(SimpleRequest) request.getAttachment();
                    _earlyEof(r);
                } else {
                    SimpleRequest r = new SimpleRequest(request, response, ot, connection);
                    request.setAttachment(r);
                    _earlyEof(r);
                }
            }
        }), null); // new WebSocketHandler() 

        http2Server.start();
    }

    override
    protected void destroy() {
        try {
            // handlerExecutorService.shutdown();
        } catch (Exception e) {
            warningf("simple http server handler pool shutdown exception", e);
        } finally {
        // TODO: Tasks pending completion -@zxp at 7/5/2018, 3:47:12 PM            
        // 
            http2Server.stop();
        }
    }

}
