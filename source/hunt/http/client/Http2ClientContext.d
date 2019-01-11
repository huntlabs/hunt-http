module hunt.http.client.Http2ClientContext;

import hunt.http.client.ClientHttpHandler;
import hunt.http.client.ClientHttp2SessionListener;
import hunt.http.client.HttpClientConnection;
import hunt.http.client.Http2ClientContext;

import hunt.http.codec.http.stream.Session;
import hunt.concurrency.Promise;

class Http2ClientContext {
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
