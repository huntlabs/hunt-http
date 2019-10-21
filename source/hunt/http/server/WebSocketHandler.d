module hunt.http.server.WebSocketHandler;

import hunt.http.codec.http.stream.HttpOutputStream;

import hunt.http.WebSocketFrame;
import hunt.http.codec.websocket.stream.IOState;
import hunt.http.WebSocketConnection;

import hunt.http.HttpRequest;
import hunt.http.HttpResponse;
import hunt.http.WebSocketPolicy;

import hunt.http.HttpConnection;

import hunt.logging.ConsoleLogger;
import hunt.Functions;

import std.conv;

/**
 * 
 */
interface WebSocketHandler {
     bool acceptUpgrade(HttpRequest request, HttpResponse response,
            HttpOutputStream output, HttpConnection connection);
    
    deprecated("Using onOpen instead.")
    alias onConnect = onOpen;

    void onOpen(WebSocketConnection connection);

    void onClosed(WebSocketConnection connection);

    WebSocketPolicy getWebSocketPolicy();

    void setWebSocketPolicy(WebSocketPolicy w);

    void onFrame(WebSocketFrame frame, WebSocketConnection connection);

    void onError(Exception t, WebSocketConnection connection);
}

alias HttpEventHandler = Func4!(HttpRequest, HttpResponse, HttpOutputStream, HttpConnection, bool);

/** 
 * 
 */
abstract class AbstractWebSocketHandler : WebSocketHandler {

    protected WebSocketPolicy defaultWebSocketPolicy;
    protected WebSocketPolicy _webSocketPolicy;

    private HttpEventHandler _acceptUpgradeHandler;
    private Action1!(WebSocketConnection) _openHandler;
    private Action1!(WebSocketConnection) _closeHandler;
    private Action2!(WebSocketFrame, WebSocketConnection) _frameHandler;
    private Action2!(Exception, WebSocketConnection) _errorHandler;

    this() {
        defaultWebSocketPolicy = WebSocketPolicy.newServerPolicy();
    }

    WebSocketPolicy getWebSocketPolicy() {
        if (_webSocketPolicy is null) {
            return defaultWebSocketPolicy;
        } else {
            return _webSocketPolicy;
        }
    }

    void setWebSocketPolicy(WebSocketPolicy w) {
        this._webSocketPolicy = w;
    }

    bool acceptUpgrade(HttpRequest request, HttpResponse response,
            HttpOutputStream output, HttpConnection connection) {
                
        version (HUNT_HTTP_DEBUG) {
            string path = request.getURI().getPath();
            infof("The connection %s will upgrade to WebSocket on path %s",
                connection.getId(), path);
        }

        if(_acceptUpgradeHandler !is null)
            return _acceptUpgradeHandler(request, response, output, connection);
        
        // no handler
        return false;
    }

    void onOpen(WebSocketConnection connection) {
        version (HUNT_HTTP_DEBUG) trace("Opened a connection with ", connection.getRemoteAddress());
        if(_openHandler !is null) 
            _openHandler(connection);
    }

    void onClosed(WebSocketConnection connection) {
        version (HUNT_HTTP_DEBUG) tracef("Connection %d closed: ", connection.getId(), connection.getRemoteAddress());
        if(_closeHandler !is null) 
            _closeHandler(connection);
    }

    void onFrame(WebSocketFrame frame, WebSocketConnection connection) {
        version (HUNT_HTTP_DEBUG) {
            tracef("The WebSocket connection %s received a frame: %s",
                    connection.getId(), frame.to!string());
        }

        if(_frameHandler !is null)
            _frameHandler(frame, connection);
    }

    void onError(Exception ex, WebSocketConnection connection) {
        version(HUNT_DEBUG) warningf("WebSocket error: ", ex.msg);
        version(HUNT_HTTP_DEBUG) error(ex);
        if(_errorHandler !is null)
            _errorHandler(ex, connection);
    }

    AbstractWebSocketHandler onAcceptUpgrade(HttpEventHandler handler) {
        _acceptUpgradeHandler = handler;
        return this;
    }

    AbstractWebSocketHandler onOpen(Action1!(WebSocketConnection) handler) {
        _openHandler = handler;
        return this;
    }

    AbstractWebSocketHandler onClosed(Action1!(WebSocketConnection) handler) {
        _closeHandler = handler;
        return this;
    }

    AbstractWebSocketHandler onFrame(Action2!(WebSocketFrame, WebSocketConnection) handler) {
        _frameHandler = handler;
        return this;
    }

    AbstractWebSocketHandler onError(Action2!(Exception, WebSocketConnection) handler) {
        _errorHandler = handler;
        return this;
    }
}


class WebSocketHandlerAdapter : AbstractWebSocketHandler {
    
}
