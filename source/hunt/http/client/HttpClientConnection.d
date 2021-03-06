module hunt.http.client.HttpClientConnection;

import hunt.http.client.ClientHttpHandler;
import hunt.http.client.Http2ClientConnection;

import hunt.http.codec.http.frame.SettingsFrame;
import hunt.http.HttpOutputStream;

import hunt.http.HttpRequest;
import hunt.http.HttpResponse;
import hunt.http.HttpConnection;
import hunt.http.WebSocketConnection;
import hunt.http.WebSocketPolicy;

import hunt.concurrency.Promise;
import hunt.io.ByteBuffer;
import hunt.collection.Collection;

// alias Response = HttpResponse;

interface HttpClientConnection : HttpConnection {

    void send(HttpRequest request, Promise!(HttpOutputStream) promise, ClientHttpHandler handler);

    void send(HttpRequest request, ClientHttpHandler handler);

    void send(HttpRequest request, ByteBuffer buffer, ClientHttpHandler handler);

    void send(HttpRequest request, ByteBuffer[] buffers, ClientHttpHandler handler);

    // void send(HttpRequest request, Collection!ByteBuffer buffers, ClientHttpHandler handler);

    HttpOutputStream sendRequestWithContinuation(HttpRequest request, ClientHttpHandler handler);

    HttpOutputStream getHttpOutputStream(HttpRequest request, ClientHttpHandler handler);

    void upgradeHttp2(HttpRequest request, SettingsFrame settings, Promise!(HttpClientConnection) promise,
                      ClientHttpHandler upgradeHandler, ClientHttpHandler http2ResponseHandler);

    void upgradeWebSocket(HttpRequest request, WebSocketPolicy policy, Promise!(WebSocketConnection) promise,
                          ClientHttpHandler upgradeHandler, IncomingFrames incomingFrames);
}
