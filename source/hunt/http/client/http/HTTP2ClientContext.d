module hunt.http.client.http.HTTP2ClientContext;

import hunt.http.client.http.ClientHTTPHandler;
import hunt.http.client.http.ClientHTTP2SessionListener;
import hunt.http.client.http.HTTPClientConnection;
import hunt.http.client.http.HTTP2ClientContext;

import hunt.http.codec.http.stream.Session;
import hunt.util.concurrent.Promise;

class HTTP2ClientContext {
    private Promise!(HTTPClientConnection) promise;
    private ClientHTTP2SessionListener listener;

    Promise!(HTTPClientConnection) getPromise() {
        return promise;
    }

    void setPromise(Promise!(HTTPClientConnection) promise) {
        this.promise = promise;
    }

    ClientHTTP2SessionListener getListener() {
        return listener;
    }

    void setListener(ClientHTTP2SessionListener listener) {
        this.listener = listener;
    }
}
