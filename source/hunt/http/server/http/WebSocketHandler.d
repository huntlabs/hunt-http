module hunt.http.server.http.WebSocketHandler;

import hunt.http.codec.http.model.MetaData;
import hunt.http.codec.http.stream.HTTPConnection;
import hunt.http.codec.http.stream.HTTPOutputStream;
// import hunt.http.codec.websocket.frame.Frame;
// import hunt.http.codec.websocket.stream.WebSocketConnection;
// import hunt.http.codec.websocket.stream.WebSocketPolicy;

import hunt.logger;


/**
 * 
 */
interface WebSocketHandler {

    bool acceptUpgrade(MetaData.Request request, MetaData.Response response,
                                  HTTPOutputStream output,
                                  HTTPConnection connection);

    // void onConnect(WebSocketConnection webSocketConnection);

    // WebSocketPolicy getWebSocketPolicy();

    // void onFrame(Frame frame, WebSocketConnection connection);

    // void onError(Throwable t, WebSocketConnection connection);

}

/**
*/
class DefaultWebSocketHandler : WebSocketHandler {

    // private WebSocketPolicy defaultWebSocketPolicy;

    this()
    {
        // defaultWebSocketPolicy = WebSocketPolicy.newServerPolicy();
    }

    bool acceptUpgrade(MetaData.Request request, MetaData.Response response,
                                  HTTPOutputStream output,
                                  HTTPConnection connection) {
        info("The connection %s will upgrade to WebSocket connection", connection.getSessionId());
        return true;
    }

    // void onConnect(WebSocketConnection webSocketConnection) {

    // }

    // WebSocketPolicy getWebSocketPolicy() {
    //     return defaultWebSocketPolicy;
    // }

    // void onFrame(Frame frame, WebSocketConnection connection) {
    //     version(HuntDebugMode) {
    //         tracef("The WebSocket connection %s received a  frame: %s", connection.getSessionId(), frame.toString());
    //     }
    // }

    // void onError(Throwable t, WebSocketConnection connection) {
    //     errorf("The WebSocket error", t);
    // }

}
