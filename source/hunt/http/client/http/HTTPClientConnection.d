module hunt.http.client.http.HTTPClientConnection;

import hunt.http.client.http.ClientHTTPHandler;
import hunt.http.client.http.HTTP2ClientConnection;

import hunt.http.codec.http.frame.SettingsFrame;
import hunt.http.codec.http.model.MetaData;
import hunt.http.codec.http.stream.HTTPConnection;
import hunt.http.codec.http.stream.HTTPOutputStream;
// import hunt.http.codec.websocket.model.IncomingFrames;
// import hunt.http.codec.websocket.stream.WebSocketConnection;
// import hunt.http.codec.websocket.stream.WebSocketPolicy;
import hunt.util.concurrent.Promise;

import hunt.container.ByteBuffer;
import hunt.container.Collection;

alias Request = MetaData.Request;
alias Response = MetaData.Response;

interface HTTPClientConnection : HTTPConnection {

    void send(Request request, Promise!(HTTPOutputStream) promise, ClientHTTPHandler handler);

    void send(Request request, ClientHTTPHandler handler);

    void send(Request request, ByteBuffer buffer, ClientHTTPHandler handler);

    void send(Request request, ByteBuffer[] buffers, ClientHTTPHandler handler);

    // void send(Request request, Collection!ByteBuffer buffers, ClientHTTPHandler handler);

    HTTPOutputStream sendRequestWithContinuation(Request request, ClientHTTPHandler handler);

    HTTPOutputStream getHTTPOutputStream(Request request, ClientHTTPHandler handler);

    void upgradeHTTP2(Request request, SettingsFrame settings, Promise!(HTTP2ClientConnection) promise,
                      ClientHTTPHandler upgradeHandler, ClientHTTPHandler http2ResponseHandler);

    // void upgradeWebSocket(Request request, WebSocketPolicy policy, Promise!(WebSocketConnection) promise,
    //                       ClientHTTPHandler upgradeHandler, IncomingFrames incomingFrames);
}
