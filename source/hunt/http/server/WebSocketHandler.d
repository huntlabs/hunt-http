module hunt.http.server.WebSocketHandler;

import hunt.http.codec.http.model.MetaData;
import hunt.http.codec.http.stream.HttpConnection;
import hunt.http.codec.http.stream.HttpOutputStream;

import hunt.http.codec.websocket.frame.Frame;
import hunt.http.codec.websocket.stream.WebSocketConnection;
import hunt.http.codec.websocket.stream.WebSocketPolicy;

import hunt.logging;


/**
 * 
 */
// interface WebSocketHandler {

//     bool acceptUpgrade(MetaData.Request request, MetaData.Response response,
//                                   HttpOutputStream output,
//                                   HttpConnection connection);

//     void onConnect(WebSocketConnection webSocketConnection);

//     WebSocketPolicy getWebSocketPolicy();

//     void onFrame(Frame frame, WebSocketConnection connection);

//     void onError(Exception t, WebSocketConnection connection);

// }

/**
*/
class WebSocketHandler {

    protected WebSocketPolicy defaultWebSocketPolicy;

    this()
    {
        defaultWebSocketPolicy = WebSocketPolicy.newServerPolicy();
    }

    bool acceptUpgrade(MetaData.Request request, MetaData.Response response,
                                  HttpOutputStream output,
                                  HttpConnection connection) {
        infof("The connection %s will upgrade to WebSocket connection", connection.getSessionId());
        return true;
    }

    void onConnect(WebSocketConnection webSocketConnection) {

    }

    WebSocketPolicy getWebSocketPolicy() {
        return defaultWebSocketPolicy;
    }

    void onFrame(Frame frame, WebSocketConnection connection) {
        version(HuntDebugMode) {
            tracef("The WebSocket connection %s received a frame: %s", 
                connection.getSessionId(), (cast(Object)frame).toString());
        }
    }

    void onError(Exception t, WebSocketConnection connection) {
        errorf("The WebSocket error", t);
    }

}
