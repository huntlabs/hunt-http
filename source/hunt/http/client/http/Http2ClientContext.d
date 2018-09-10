module hunt.http.client.http.Http2ClientContext;

import hunt.http.client.http.ClientHttpHandler;
import hunt.http.client.http.ClientHttp2SessionListener;
import hunt.http.client.http.HttpClientConnection;
import hunt.http.client.http.Http2ClientContext;

import hunt.http.codec.http.stream.Session;
import hunt.util.concurrent.Promise;

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
