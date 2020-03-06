module hunt.http.client.RealCall;

import hunt.http.client.Call;
import hunt.http.client.ClientHttpHandler;

import hunt.http.client.HttpClient;
import hunt.http.client.HttpClientConnection;
import hunt.http.client.HttpClientResponse;
import hunt.http.client.HttpClientRequest;
import hunt.http.client.Http1ClientConnection;
import hunt.http.client.RequestBody;

import hunt.http.HttpOptions;
import hunt.http.HttpConnection;
import hunt.http.codec.http.stream.HttpOutputStream;
import hunt.http.HttpConnection;
import hunt.http.codec.http.model.HttpFields;
import hunt.http.codec.http.model.HttpField;
import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.model.HttpMethod;
import hunt.http.codec.http.model.HttpStatus;
import hunt.http.HttpVersion;
import hunt.net.util.HttpURI;
import hunt.http.codec.http.model.MetaData;

import hunt.collection.ByteBuffer;
import hunt.collection.BufferUtils;
import hunt.concurrency.FuturePromise;
import hunt.Exceptions;
// import hunt.net.NetUtil;
import hunt.logging.ConsoleLogger;
import hunt.net.TcpSslOptions;
import hunt.net.NetClientOptions;
import hunt.util.Traits;

import core.atomic;
import core.sync.condition;
import core.sync.mutex;

import std.conv;
import std.format;
import std.parallelism;


/**
 * 
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
        
        version(WITH_HUNT_TRACE) {
            originalRequest.startSpan();
        }

        HttpClientResponse hcr;

        AbstractClientHttpHandler httpHandler = new class AbstractClientHttpHandler {

            override bool content(ByteBuffer item, HttpRequest request, HttpResponse response, 
                    HttpOutputStream output, HttpConnection connection) {
                
                HttpClientResponse clientResponse = cast(HttpClientResponse)response;
                assert(clientResponse !is null);
                
                version (HUNT_HTTP_DEBUG) tracef("ContentType: %s, ContentLength: %d", 
                    response.getContentType(), response.getContentLength());

                version (HUNT_HTTP_DEBUG_MORE) {
                    tracef("content: %s", cast(string)item.getRemaining());
                }

                clientResponse.setBody(new ResponseBody(response.getContentType(), 
                    response.getContentLength(), BufferUtils.clone(item)));
                return false;
            }

            override bool messageComplete(HttpRequest request, HttpResponse response,
                    HttpOutputStream output, HttpConnection connection) {
                version (HUNT_HTTP_DEBUG) trace(response.getFields());
                
                synchronized {
                    hcr = cast(HttpClientResponse)response;
                    assert(hcr !is null);
                }
                responseCondition.notifyAll();
                return true;
            }

        };

        doRequestTask(httpHandler);

        HttpOptions options = client.getHttpConfiguration();
        TcpSslOptions tcpOptions = options.tcpOptions(); 
        Duration idleTimeout = tcpOptions.getIdleTimeout();     

        if(hcr is null) {
            if(idleTimeout.isNegative()) {
                responseCondition.wait();
            } else {  
                version (HUNT_HTTP_DEBUG) infof("waitting for response in %s ...", idleTimeout);
                bool r = responseCondition.wait(idleTimeout);
                if(!r) {
                    string msg = format("No any response in %s", idleTimeout);
                    warningf(msg);

                    client.close();
                    version(WITH_HUNT_TRACE) {
                        originalRequest.endTraceSpan(HttpStatus.INTERNAL_SERVER_ERROR_500, msg);
                    }    
                    throw new TimeoutException();
                }
            }
        }
        version (HUNT_HTTP_DEBUG) info("response normally");
        version(WITH_HUNT_TRACE) {
            originalRequest.endTraceSpan(hcr.getStatus(), null);
        }
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
                HttpClientResponse hcr = cast(HttpClientResponse)response;
                hcr.setBody(new ResponseBody(response.getContentType(), 
                    response.getContentLength(), BufferUtils.clone(item)));
                return false;
            }

            override bool messageComplete(HttpRequest request, HttpResponse response,
                    HttpOutputStream output, HttpConnection connection) {
                version (HUNT_HTTP_DEBUG) trace(response.getFields());
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
    }

    void doRequestTask(AbstractClientHttpHandler httpHandler) {
        HttpURI uri = originalRequest.getURI();
        string scheme = uri.getScheme();
        int port = uri.getPort();

        version(HUNT_HTTP_DEBUG) tracef("new request: scheme=%s, host=%s, port=%d", 
            scheme, uri.getHost(), port);

        FuturePromise!HttpClientConnection promise = new FuturePromise!HttpClientConnection();

        if(port <= 0)
            port = SchemePortMap[scheme];
        
        HttpConnection connection;
        try {
            client.connect(uri.getHost(), port, promise);
            NetClientOptions tcpConfig = cast(NetClientOptions)client.getHttpConfiguration().tcpOptions();
            connection = promise.get(tcpConfig.getConnectTimeout());
        } catch(Exception ex) {
            string msg = "Failed to connect " ~ uri.getHost() ~ ":" ~ port.to!string();
            version(HUNT_DEBUG) {
                warning(msg, " Reason: ", ex.msg);
            }
            version(HUNT_HTTP_DEBUG) warning(ex);
            client.close();

            version(WITH_HUNT_TRACE) {
                originalRequest.endTraceSpan(HttpStatus.INTERNAL_SERVER_ERROR_500, msg);
            }
            throw new IOException(msg);
        }
        
        version (HUNT_HTTP_DEBUG) info(connection.getHttpVersion());

        if (connection.getHttpVersion() == HttpVersion.HTTP_1_1) {
            Http1ClientConnection http1ClientConnection = cast(Http1ClientConnection) connection;
            RequestBody rb = originalRequest.getBody();

            if(HttpMethod.permitsRequestBody(originalRequest.getMethod()) && rb !is null) {
                // http1ClientConnection.send(originalRequest, rb.content(), httpHandler);
                HttpOutputStream output = http1ClientConnection.getHttpOutputStream(originalRequest, httpHandler);
                rb.writeTo(output);
            } else {
                http1ClientConnection.send(originalRequest, httpHandler);
            }
        } else {
            // TODO: Tasks pending completion -@zxp at 6/4/2019, 5:55:40 PM
            // 
            string msg = "Unsupported " ~ connection.getHttpVersion().toString();
            version(WITH_HUNT_TRACE) {
                originalRequest.endTraceSpan(HttpStatus.INTERNAL_SERVER_ERROR_500, msg);
            }
            throw new IOException(msg);
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