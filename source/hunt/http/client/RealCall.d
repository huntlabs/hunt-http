module hunt.http.client.RealCall;

import hunt.http.client.Call;
import hunt.http.client.ClientHttpHandler;
import hunt.http.client.CookieStore;
import hunt.http.client.HttpClient;
import hunt.http.client.HttpClientConnection;
import hunt.http.client.HttpClientResponse;
import hunt.http.client.HttpClientRequest;
import hunt.http.client.Http1ClientConnection;

import hunt.http.Cookie;
import hunt.http.HttpBody;
import hunt.http.HttpConnection;
import hunt.http.HttpConnection;
import hunt.http.HttpFields;
import hunt.http.HttpField;
import hunt.http.HttpHeader;
import hunt.http.HttpMethod;
import hunt.http.HttpOptions;
import hunt.http.HttpOutputStream;
import hunt.http.HttpRequest;
import hunt.http.HttpResponse;
import hunt.http.HttpStatus;
import hunt.http.HttpVersion;

import hunt.collection.ByteBuffer;
import hunt.collection.BufferUtils;
import hunt.concurrency.FuturePromise;
import hunt.Exceptions;
// import hunt.net.NetUtil;
import hunt.logging.ConsoleLogger;
import hunt.net.KeyCertOptions;
import hunt.net.PemKeyCertOptions;
import hunt.net.TcpSslOptions;
import hunt.net.NetClientOptions;
import hunt.net.util.HttpURI;
import hunt.util.Traits;

import core.atomic;
import core.sync.condition;
import core.sync.mutex;

import std.conv;
import std.format;
import std.parallelism;

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
                client.getHttpOptions().isSecureConnectionEnabled(true);
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

            override bool headerComplete(HttpRequest request, HttpResponse response,
                    HttpOutputStream output, HttpConnection connection) {
                version(HUNT_HTTP_DEBUG) info("headerComplete!");
                    
                HttpClientRequest req = cast(HttpClientRequest)request;
                assert(req !is null);

                HttpClientResponse res = cast(HttpClientResponse)response;
                assert(res !is null);

                if(req.isCookieStoreEnabled()) {
                    CookieStore store = client.getCookieStore();
                    if(store !is null) {
                        foreach(Cookie c; res.cookies()) {
                            store.add(request.getURI(), c);
                        }
                    }
                }

                return true;
            }

            override bool content(ByteBuffer item, HttpRequest request, HttpResponse response, 
                    HttpOutputStream output, HttpConnection connection) {
                
                HttpClientResponse clientResponse = cast(HttpClientResponse)response;
                assert(clientResponse !is null);
                
                version (HUNT_HTTP_DEBUG) tracef("ContentType: %s, ContentLength: %d, current content size: %d", 
                    response.getContentType(), response.getContentLength(), item.remaining());

                version (HUNT_HTTP_DEBUG_MORE) {
                    tracef("content: %s", cast(string)item.getRemaining());
                }

                // clientResponse.setBody(new ResponseBody(response.getContentType(), 
                //     response.getContentLength(), BufferUtils.clone(item)));

                HttpBody hb = clientResponse.getBody();
                if(hb is null) {
                    hb = HttpBody.create(response.getContentType(), response.getContentLength());
                    clientResponse.setBody(hb); 
                } 
                hb.append(item);

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

        HttpOptions options = client.getHttpOptions();
        // options = new HttpOptions(options); // clone the options
        // FIXME: Needing refactor or cleanup -@zhangxueping at 2019-12-12T18:13:36+08:00
        // clone the options
        if(originalRequest.isCertificateAuth()) {
            options.isCertificateAuth = originalRequest.isCertificateAuth();
            options.setKeyCertOptions(originalRequest.getKeyCertOptions());
        }

        doRequestTask(httpHandler);

        if(hcr is null) {        
            TcpSslOptions tcpOptions = options.getTcpConfiguration();     
            Duration idleTimeout = tcpOptions.getIdleTimeout();     
            if(idleTimeout.isNegative()) {
                version (HUNT_HTTP_DEBUG) infof("waitting for response...");
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
                // hcr.setBody(new ResponseBody(response.getContentType(), 
                //     response.getContentLength(), BufferUtils.clone(item)));

                HttpBody hb = hcr.getBody();
                if(hb is null) {
                    hb = HttpBody.create(response.getContentType(), response.getContentLength());
                    hcr.setBody(hb); 
                } 
                hb.append(item);

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

        // port
        int port = uri.getPort();
        version(HUNT_HTTP_DEBUG) infof("new request: scheme=%s, host=%s, port=%d", 
            scheme, uri.getHost(), port);
        if(port <= 0)
            port = SchemePortMap[scheme];

        // set cookie from cookie store
        if(originalRequest.isCookieStoreEnabled()) {
            CookieStore store = client.getCookieStore();
            HttpFields fields = originalRequest.getFields();
            
            if(store !is null && fields !is null) {
                auto cookies = store.getCookies();
                
                if(cookies !is null)
                    fields.put(HttpHeader.COOKIE, generateCookies(store.getCookies()));
            }
        }

        // opentracing: initialize TraceContext


        FuturePromise!HttpClientConnection promise = new FuturePromise!HttpClientConnection();
        HttpConnection connection;
        try {
            NetClientOptions tcpConfig = cast(NetClientOptions)client.getHttpOptions().getTcpConfiguration();
            client.connect(uri.getHost(), port, promise);
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
            // HttpBody rb = originalRequest.getBody();
            if(HttpMethod.permitsRequestBody(originalRequest.getMethod())) { // && rb !is null
                // http1ClientConnection.send(originalRequest, rb.content(), httpHandler);
                HttpOutputStream output = http1ClientConnection.getHttpOutputStream(originalRequest, httpHandler);
                // rb.writeTo(output);
                output.close(); // End a request, and keep the connection for waiting for the respons.
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
        implementationMissing(false);
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