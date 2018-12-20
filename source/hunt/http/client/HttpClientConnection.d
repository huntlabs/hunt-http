module hunt.http.client.HttpClientConnection;

import hunt.http.client.ClientHttpHandler;
import hunt.http.client.Http2ClientConnection;

import hunt.http.codec.http.frame.SettingsFrame;
import hunt.http.codec.http.model.MetaData;
import hunt.http.codec.http.stream.HttpConnection;
import hunt.http.codec.http.stream.HttpOutputStream;
import hunt.http.codec.websocket.model.IncomingFrames;
import hunt.http.codec.websocket.stream.WebSocketConnection;
import hunt.http.codec.websocket.stream.WebSocketPolicy;
import hunt.concurrent.Promise;

import hunt.container.ByteBuffer;
import hunt.container.Collection;

alias Request = HttpRequest;
alias Response = HttpResponse;

interface HttpClientConnection : HttpConnection {

    void send(Request request, Promise!(HttpOutputStream) promise, ClientHttpHandler handler);

    void send(Request request, ClientHttpHandler handler);

    void send(Request request, ByteBuffer buffer, ClientHttpHandler handler);

    void send(Request request, ByteBuffer[] buffers, ClientHttpHandler handler);

    // void send(Request request, Collection!ByteBuffer buffers, ClientHttpHandler handler);

    HttpOutputStream sendRequestWithContinuation(Request request, ClientHttpHandler handler);

    HttpOutputStream getHttpOutputStream(Request request, ClientHttpHandler handler);

    void upgradeHttp2(Request request, SettingsFrame settings, Promise!(HttpClientConnection) promise,
                      ClientHttpHandler upgradeHandler, ClientHttpHandler http2ResponseHandler);

    void upgradeWebSocket(Request request, WebSocketPolicy policy, Promise!(WebSocketConnection) promise,
                          ClientHttpHandler upgradeHandler, IncomingFrames incomingFrames);
}
