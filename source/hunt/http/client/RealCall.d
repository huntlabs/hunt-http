module hunt.http.client.RealCall;

import hunt.http.client.Call;
import hunt.http.client.ClientHttpHandler;

import hunt.http.client.HttpClient;
import hunt.http.client.HttpClientConnection;
import hunt.http.client.HttpClientResponse;
import hunt.http.client.HttpClientRequest;


import hunt.http.client.Http1ClientConnection;
import hunt.http.codec.http.stream.HttpConfiguration;
import hunt.http.codec.http.stream.HttpConnection;
import hunt.http.codec.http.stream.HttpOutputStream;
import hunt.http.codec.http.stream.HttpConnection;
import hunt.http.codec.http.model.HttpURI;
import hunt.http.codec.http.model.HttpVersion;
import hunt.http.codec.http.model.MetaData;

import hunt.concurrency.FuturePromise;
import hunt.collection.ByteBuffer;
import hunt.collection.BufferUtils;
import hunt.Exceptions;
// import hunt.net.NetUtil;
import hunt.logging.ConsoleLogger;

import core.sync.condition;
import core.sync.mutex;

class RealCall : Call {
    HttpClient client;

    /**
     * There is a cycle between the {@link Call} and {@link Transmitter} that makes this awkward.
     * This is set after immediately after creating the call instance.
     */
    // private HttpClientConnection transmitter;

    /** The application's original request unadulterated by redirects or auth headers. */
    Request originalRequest;
    bool forWebSocket;

    // Guarded by this.
    private bool executed;
Mutex responseLocker;
Condition responseCondition;

    private this(HttpClient client, Request originalRequest, bool forWebSocket) {
        this.client = client;
        this.originalRequest = originalRequest;
        this.forWebSocket = forWebSocket;

		responseLocker = new Mutex();
		responseCondition = new Condition(responseLocker);
    }

    static RealCall newRealCall(HttpClient client, Request originalRequest, bool forWebSocket) {

        // Safely publish the Call instance to the EventListener.
        RealCall call = new RealCall(client, originalRequest, forWebSocket);
        // call.transmitter = new Http1ClientConnection(client, call);
        return call;
    }

    Request request() {
        return originalRequest;
    }

    Response execute() {
        responseLocker.lock();
        scope(exit) {
            responseLocker.unlock();
        }

        if (executed) throw new IllegalStateException("Already Executed");
        executed = true;

        HttpURI uri = originalRequest.getURI();

        FuturePromise!HttpClientConnection promise = new FuturePromise!HttpClientConnection();
        int port  = uri.getPort();
        client.connect(uri.getHost(), port == -1 ? 80 : port, promise);
        
        HttpConnection connection;
        try {
            connection = promise.get();
        } catch(Exception ex) {
            warning(ex.msg);
            // Thread.sleep(2.seconds);
            // NetUtil.stopEventLoop();
            return null;
        }
        
        version (HUNT_HTTP_DEBUG) info(connection.getHttpVersion());
        HttpClientResponse hcr;

        if (connection.getHttpVersion() == HttpVersion.HTTP_1_1) {
            Http1ClientConnection http1ClientConnection = cast(Http1ClientConnection) connection;
            http1ClientConnection.send(originalRequest, new class AbstractClientHttpHandler {

                override bool content(ByteBuffer item, HttpRequest request, HttpResponse response, 
                        HttpOutputStream output, HttpConnection connection) {
                    // trace(BufferUtils.toString(item));
                    hcr = cast(HttpClientResponse)response;
                    hcr.setBody(new ResponseBody(response.getContentType(), response.getContentLength(), item));
                    return false;
                }

                override bool messageComplete(HttpRequest request, HttpResponse response,
                        HttpOutputStream output, HttpConnection connection) {
                    // trace(response);
                    version (HUNT_DEBUG) trace(response.getFields());
                    responseCondition.notifyAll();
                    return true;
                }

            });
        }

        version (HUNT_HTTP_DEBUG) info("waitting response...");
        responseCondition.wait();
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