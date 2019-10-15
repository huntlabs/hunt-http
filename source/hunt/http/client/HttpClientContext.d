module hunt.http.client.HttpClientContext;

import hunt.http.client.ClientHttpHandler;
import hunt.http.client.ClientHttp2SessionListener;
import hunt.http.client.HttpClientConnection;
import hunt.http.client.HttpClientContext;

import hunt.http.codec.http.stream.Session;
import hunt.concurrency.Promise;

/**
 * 
 */
class HttpClientContext {

    private Promise!(HttpClientConnection) promise;
    private ClientHttp2SessionListener listener;

    Promise!(HttpClientConnection) getPromise() {
        return promise;
    }

    void setPromise(Promise!(HttpClientConnection) promise) {
        this.promise = promise;
    }

    ClientHttp2SessionListener getListener() {
        return listener;
    }

    void setListener(ClientHttp2SessionListener listener) {
        this.listener = listener;
    }
}
