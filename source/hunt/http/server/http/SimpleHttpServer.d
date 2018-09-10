module hunt.http.server.http.SimpleHttpServer;

import hunt.http.server.http.Http2Server;
import hunt.http.server.http.HttpServerConnection;
import hunt.http.server.http.ServerHttpHandler;
import hunt.http.server.http.SimpleHttpServerConfiguration;
import hunt.http.server.http.SimpleRequest;
import hunt.http.server.http.WebSocketHandler;

import hunt.http.codec.http.model.HttpStatus;
import hunt.http.codec.http.model.MetaData;

import hunt.http.codec.http.stream.HttpConnection;
import hunt.http.codec.http.stream.HttpOutputStream;

// import hunt.http.codec.websocket.frame.Frame;
// import hunt.http.codec.websocket.stream.WebSocketConnection;
import hunt.http.codec.websocket.stream.WebSocketPolicy;

import hunt.logging;

import hunt.util.Charset;
import hunt.util.exception;
import hunt.util.functional;
import hunt.io;
import hunt.util.LifeCycle;

import hunt.container.HashMap;
import hunt.container.Map;

/**
*/
class SimpleHttpServer : AbstractLifeCycle { 

    private static  int defaultPoolSize = 10; // int.getInteger("hunt.http.server.http.async.defaultPoolSize", Runtime.getRuntime().availableProcessors());

    private Http2Server http2Server;
    private SimpleHttpServerConfiguration configuration;

    private Action1!SimpleRequest _headerComplete;
    private Action3!(int, string, SimpleRequest) _badMessage;
    private Action1!SimpleRequest _earlyEof;
    private Action1!HttpConnection _acceptConnection;
    private Action2!(SimpleRequest, HttpServerConnection) tunnel;

    // private Meter requestMeter;
    // private ExecutorService handlerExecutorService;

    private Map!(string, WebSocketHandler) webSocketHandlerMap = new HashMap!(string, WebSocketHandler)();
    private WebSocketPolicy _webSocketPolicy;

    this() {
        this(new SimpleHttpServerConfiguration());
    }

    this(SimpleHttpServerConfiguration configuration) {
        this.configuration = configuration;
        // TODO: Tasks pending completion -@zxp at 7/5/2018, 2:59:11 PM
        // 
        // requestMeter = this.configuration.getTcpConfiguration()
        //                                  .getMetricReporterFactory()
        //                                  .getMetricRegistry()
        //                                  .meter("http2.SimpleHttpServer.request.count");
        // handlerExecutorService = new ForkJoinPool(defaultPoolSize, (pool) {
        //     ForkJoinWorkerThread workerThread = ForkJoinPool.defaultForkJoinWorkerThreadFactory.newThread(pool);
        //     workerThread.setName("hunt-http-server-handler-pool-" ~ workerThread.getPoolIndex());
        //     return workerThread;
        // }, null, true);
    }

    SimpleHttpServer acceptHttpTunnelConnection(Action2!(SimpleRequest, HttpServerConnection) tunnel) {
        this.tunnel = tunnel;
        return this;
    }

    SimpleHttpServer headerComplete(Action1!SimpleRequest h) {
        this._headerComplete = h;
        return this;
    }

    SimpleHttpServer earlyEof(Action1!SimpleRequest e) {
        this._earlyEof = e;
        return this;
    }

    SimpleHttpServer badMessage(Action3!(int, string, SimpleRequest) b) {
        this._badMessage = b;
        return this;
    }

    SimpleHttpServer acceptConnection(Action1!HttpConnection a) {
        this._acceptConnection = a;
        return this;
    }

    SimpleHttpServer registerWebSocket(string uri, WebSocketHandler webSocketHandler) {
        webSocketHandlerMap.put(uri, webSocketHandler);
        return this;
    }

    SimpleHttpServer webSocketPolicy(WebSocketPolicy w) {
        this._webSocketPolicy = w;
        return this;
    }

    // ExecutorService getNetExecutorService() {
    //     return http2Server.getNetExecutorService();
    // }

    // ExecutorService getHandlerExecutorService() {
    //     return handlerExecutorService;
    // }

    SimpleHttpServerConfiguration getConfiguration() {
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
    protected void initilize() {

        // class SimpleWebSocketHandler : WebSocketHandler
        // {
        //     override
        //     bool acceptUpgrade(MetaData.Request request, MetaData.Response response,
        //                                  HttpOutputStream output,
        //                                  HttpConnection connection) {
        //         info("The connection %s will upgrade to WebSocket connection", connection.getSessionId());
        //         WebSocketHandler handler = webSocketHandlerMap.get(request.getURI().getPath());
        //         if (handler == null) {
        //             response.setStatus(HttpStatus.BAD_REQUEST_400);
        //             try (HttpOutputStream ot = output) {
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

        http2Server = new Http2Server(configuration.getHost(), configuration.getPort(), configuration, 
            new ServerHttpHandlerAdapter().acceptConnection(_acceptConnection).acceptHttpTunnelConnection((request, 
                response, ot, connection) {
            SimpleRequest r = new SimpleRequest(request, response, ot, cast(HttpConnection)connection);
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
