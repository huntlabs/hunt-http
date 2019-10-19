module hunt.http.WebSocketMessageHandler;

import hunt.http.codec.websocket.stream.WebSocketConnection;

import hunt.collection.ByteBuffer;
import hunt.Exceptions;
import hunt.logging.ConsoleLogger;


/**
 * 
 */
interface WebSocketMessageHandler {

    void onOpen(WebSocketConnection connection);

    void onClosed(WebSocketConnection connection); // CloseStatus closeStatus

    void onPing(WebSocketConnection connection);

    void onPong(WebSocketConnection connection);
    
    void onText(string text, WebSocketConnection connection);

    void onBinary(ByteBuffer buffer, WebSocketConnection connection);

    void onContinuation(ByteBuffer buffer, WebSocketConnection connection);

    void onError(Exception exception, WebSocketConnection connection);
}

/**
 * 
 */
abstract class AbstractWebSocketMessageHandler : WebSocketMessageHandler {

    void onOpen(WebSocketConnection connection)  { implementationMissing(false); }

    void onClosed(WebSocketConnection connection)  { 
        version(HUNT_HTTP_DEBUG) infof("closed with %s", connection.getRemoteAddress());
    }

    void onPing(WebSocketConnection connection)  { 
        version(HUNT_HTTP_DEBUG) tracef("ping from %s", connection.getRemoteAddress()); 
    }

    void onPong(WebSocketConnection connection)  { 
        version(HUNT_HTTP_DEBUG) tracef("ping from %s", connection.getRemoteAddress());
    }
    
    void onText(string text, WebSocketConnection connection)  { 
        version(HUNT_HTTP_DEBUG) tracef("received (from %s): %s", connection.getRemoteAddress(), text); 
     }

    void onBinary(ByteBuffer buffer, WebSocketConnection connection)  { implementationMissing(false); }

    void onContinuation(ByteBuffer buffer, WebSocketConnection connection)  { implementationMissing(false); }

    void onError(Exception ex, WebSocketConnection connection)  { 
        debug warningf("error (from %s): %s", connection.getRemoteAddress(), ex.msg);
        version(HUNT_DEBUG) warning(ex);
    }
}
