module hunt.http.client.RealCall;

import hunt.http.client.Call;
import hunt.http.client.ClientHttpHandler;

import hunt.http.client.HttpClient;
import hunt.http.client.HttpClientConnection;
import hunt.http.client.HttpClientResponse;
import hunt.http.client.HttpClientRequest;
import hunt.http.client.Http1ClientConnection;
import hunt.http.client.RequestBody;

import hunt.http.codec.http.stream.HttpConfiguration;
import hunt.http.codec.http.stream.HttpConnection;
import hunt.http.codec.http.stream.HttpOutputStream;
import hunt.http.codec.http.stream.HttpConnection;
import hunt.http.codec.http.model.HttpFields;
import hunt.http.codec.http.model.HttpField;
import hunt.http.codec.http.model.HttpMethod;
import hunt.http.codec.http.model.HttpVersion;
import hunt.http.codec.http.model.HttpURI;
import hunt.http.codec.http.model.MetaData;

import hunt.concurrency.FuturePromise;
import hunt.collection.ByteBuffer;
import hunt.collection.BufferUtils;
import hunt.Exceptions;
// import hunt.net.NetUtil;
import hunt.logging.ConsoleLogger;

import hunt.Exceptions;

import core.atomic;
import core.sync.condition;
import core.sync.mutex;

import std.parallelism;

import hunt.util.Traits;

/**
*/
class RealCall : Call {
    private HttpClient client;

    /** The application's original request unadulterated by redirects or auth headers. */
    private Request originalRequest;
    private bool forWebSocket;

    // Guarded by this.
    private bool executed;
    private Mutex responseLocker;
    private Condition responseCondition;

    private this(HttpClient client, Request request, bool forWebSocket) {
        this.client = client;
        this.originalRequest = request;
        this.forWebSocket = forWebSocket;
        
        version(WITH_HUNT_SECURITY) {
            if(request.isHttps()) {
                client.getHttpConfiguration().setSecureConnectionEnabled(true);
                // import hunt.net.secure.conscrypt.ConscryptSecureSessionFactory;
                // client.getHttpConfiguration().setSecureSessionFactory(new ConscryptSecureSessionFactory());
            }
        }
		responseLocker = new Mutex();
		responseCondition = new Condition(responseLocker);
    }

    static RealCall newRealCall(HttpClient client, Request request, bool forWebSocket) {
        // Safely publish the Call instance to the EventListener.
        RealCall call = new RealCall(client, request, forWebSocket);
        return call;
    }

    Request request() {
        return originalRequest;
    }

    Response execute() {
        synchronized (this) {
            if (executed) throw new IllegalStateException("Already Executed");
                executed = true;
        }
        responseLocker.lock();
        scope(exit) {
            responseLocker.unlock();
        }
        
        HttpClientResponse hcr;

        AbstractClientHttpHandler httpHandler = new class AbstractClientHttpHandler {

            override bool content(ByteBuffer item, HttpRequest request, HttpResponse response, 
                    HttpOutputStream output, HttpConnection connection) {
                synchronized {
                    hcr = cast(HttpClientResponse)response;
                }
                hcr.setBody(new ResponseBody(response.getContentType(), 
                    response.getContentLength(), BufferUtils.clone(item)));
                return false;
            }

            override bool messageComplete(HttpRequest request, HttpResponse response,
                    HttpOutputStream output, HttpConnection connection) {
                version (HUNT_HTTP_DEBUG) trace(response.getFields());
                responseCondition.notifyAll();
                return true;
            }

        };

        doRequestTask(httpHandler);

        version (HUNT_HTTP_DEBUG) info("waitting response...");
        synchronized {
            if(hcr is null)
                responseCondition.wait();
        }
        version (HUNT_HTTP_DEBUG) info("response normally");
        return hcr;

    }

    void enqueue(Callback responseCallback) {
        synchronized (this) {
            if (executed) throw new IllegalStateException("Already Executed");
                executed = true;
        }
        // transmitter.callStart();
        // client.dispatcher().enqueue(new AsyncCall(responseCallback));

        AbstractClientHttpHandler httpHandler = new class AbstractClientHttpHandler {
            override bool content(ByteBuffer item, HttpRequest request, HttpResponse response, 
                    HttpOutputStream output, HttpConnection connection) {
                // trace(BufferUtils.toString(item));
                HttpClientResponse hcr = cast(HttpClientResponse)response;
                hcr.setBody(new ResponseBody(response.getContentType(), 
                    response.getContentLength(), BufferUtils.clone(item)));
                return false;
            }

            override bool messageComplete(HttpRequest request, HttpResponse response,
                    HttpOutputStream output, HttpConnection connection) {
                // trace(response);
                version (HUNT_DEBUG) trace(response.getFields());
                responseCallback.onResponse(this.outer, cast(HttpClientResponse)response);
                return true;
            }

        };

        httpHandler.badMessage((int status, string reason, HttpRequest request,
                    HttpResponse response, HttpOutputStream output, HttpConnection connection) {
                import std.format;
                string msg = format("status: %d, reason: %s", status, reason);
                responseCallback.onFailure(this, new IOException(msg));
        });

        try {
            doRequestTask(httpHandler);
            // auto requestTask = task(&doRequestTask, httpHandler);
            // requestTask.executeInNewThread();            
        } catch(IOException ex) {
            responseCallback.onFailure(this, ex);
        }
        // doRequestTask(responseCallback);
        // auto requestTask = task(&doRequestTask);
        // requestTask.executeInNewThread();
    }

    void doRequestTask(AbstractClientHttpHandler httpHandler) {
            HttpURI uri = originalRequest.getURI();
            string scheme = uri.getScheme();
            int port = uri.getPort();

            version(HUNT_DEBUG) tracef("new request: scheme=%s, host=%s, port=%d", 
                scheme, uri.getHost(), port);

            FuturePromise!HttpClientConnection promise = new FuturePromise!HttpClientConnection();

            if(port <= 0)
                port = SchemePortMap[scheme];
            
            HttpConnection connection;
            try {
                client.connect(uri.getHost(), port, promise);
                connection = promise.get();
            } catch(Exception ex) {
                throw new IOException(ex.msg);
            }
            
            version (HUNT_HTTP_DEBUG) info(connection.getHttpVersion());

            if (connection.getHttpVersion() == HttpVersion.HTTP_1_1) {

                Http1ClientConnection http1ClientConnection = cast(Http1ClientConnection) connection;
                RequestBody rb = originalRequest.getBody();
                if(HttpMethod.permitsRequestBody(originalRequest.getMethod()) && rb !is null) {
                    http1ClientConnection.send(originalRequest, rb.content(), httpHandler);
                } else {
                    http1ClientConnection.send(originalRequest, httpHandler);
                }
            } else {
                // TODO: Tasks pending completion -@zxp at 6/4/2019, 5:55:40 PM
                // 
                string msg = "Unsupported " ~ connection.getHttpVersion().toString();
                throw new IOException(msg);
            }

            version (HUNT_HTTP_DEBUG) info("waitting response...");        
    }

    
        void doRequestTask(Callback responseCallback) {
            HttpURI uri = originalRequest.getURI();
            string scheme = uri.getScheme();
            int port = uri.getPort();

            version(HUNT_DEBUG) tracef("new request: scheme=%s, host=%s, port=%d", 
                scheme, uri.getHost(), port);

            FuturePromise!HttpClientConnection promise = new FuturePromise!HttpClientConnection();

            if(port <= 0)
                port = SchemePortMap[scheme];
            client.connect(uri.getHost(), port, promise);
            
            HttpConnection connection;
            try {
                connection = promise.get();
            } catch(Exception ex) {
                warning(ex.msg);
                responseCallback.onFailure(this, new IOException(ex.msg));
                return;
            }
            
            version (HUNT_HTTP_DEBUG) info(connection.getHttpVersion());

            if (connection.getHttpVersion() == HttpVersion.HTTP_1_1) {

                AbstractClientHttpHandler httpHandler = new class AbstractClientHttpHandler {

                    override bool content(ByteBuffer item, HttpRequest request, HttpResponse response, 
                            HttpOutputStream output, HttpConnection connection) {
                        // trace(BufferUtils.toString(item));
                        HttpClientResponse hcr = cast(HttpClientResponse)response;
                        hcr.setBody(new ResponseBody(response.getContentType(), 
                            response.getContentLength(), BufferUtils.clone(item)));
                        return false;
                    }

                    override bool messageComplete(HttpRequest request, HttpResponse response,
                            HttpOutputStream output, HttpConnection connection) {
                        // trace(response);
                        version (HUNT_DEBUG) trace(response.getFields());
                        responseCallback.onResponse(this.outer, cast(HttpClientResponse)response);
                        return true;
                    }

                };

                httpHandler.badMessage((int status, string reason, HttpRequest request,
                            HttpResponse response, HttpOutputStream output, HttpConnection connection) {
                        import std.format;
                        string msg = format("status: %d, reason: %s", status, reason);
                        responseCallback.onFailure(this, new IOException(msg));
                });

                Http1ClientConnection http1ClientConnection = cast(Http1ClientConnection) connection;
                RequestBody rb = originalRequest.getBody();
                if(HttpMethod.permitsRequestBody(originalRequest.getMethod()) && rb !is null) {
                    http1ClientConnection.send(originalRequest, rb.content(), httpHandler);
                } else {
                    http1ClientConnection.send(originalRequest, httpHandler);
                }
            } else {
                // TODO: Tasks pending completion -@zxp at 6/4/2019, 5:55:40 PM
                // 
                string msg = "Unsupported " ~ connection.getHttpVersion().toString();
                warning(msg);
                responseCallback.onFailure(this, new IOException(msg));
            }

            version (HUNT_HTTP_DEBUG) info("waitting response...");
        }

    void cancel() {
        // transmitter.cancel();
    }

    // Timeout timeout() {
    //     return transmitter.timeout();
    // }

    bool isExecuted() {
        return executed;
    }

    bool isCanceled() {
        // return transmitter.isCanceled();
        
        return false;
    }
    
}