module hunt.http.server.WebSocketHandler;

import hunt.http.codec.http.model.MetaData;
import hunt.http.codec.http.stream.HttpConnection;
import hunt.http.codec.http.stream.HttpOutputStream;

import hunt.http.codec.websocket.frame.Frame;
import hunt.http.codec.websocket.stream.WebSocketConnection;
import hunt.http.codec.websocket.stream.WebSocketPolicy;

import hunt.logging;

/**
*/
class WebSocketHandler {

    protected WebSocketPolicy defaultWebSocketPolicy;
    protected WebSocketPolicy _webSocketPolicy;

    this() {
        defaultWebSocketPolicy = WebSocketPolicy.newServerPolicy();
    }

    bool acceptUpgrade(HttpRequest request, HttpResponse response,
            HttpOutputStream output, HttpConnection connection) {
        version (HUNT_DEBUG) {
            infof("The connection %s will upgrade to WebSocket connection",
                    connection.getSessionId());
        }
        return true;
    }

    void onConnect(WebSocketConnection webSocketConnection) {

    }

    WebSocketPolicy getWebSocketPolicy() {
        if (_webSocketPolicy is null) {
            return defaultWebSocketPolicy;
        }
        else {
            return _webSocketPolicy;
        }
    }

    void setWebSocketPolicy(WebSocketPolicy w) {
        this._webSocketPolicy = w;
    }

    void onFrame(Frame frame, WebSocketConnection connection) {
        version (HUNT_DEBUG) {
            tracef("The WebSocket connection %s received a frame: %s",
                    connection.getSessionId(), (cast(Object) frame).toString());
        }
    }

    void onError(Exception t, WebSocketConnection connection) {
        errorf("The WebSocket error", t);
    }

}
