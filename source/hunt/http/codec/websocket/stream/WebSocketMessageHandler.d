module hunt.http.codec.websocket.stream.WebSocketMessageHandler;

import hunt.http.codec.websocket.stream.WebSocketConnection;
import hunt.http.codec.websocket.frame.DataFrame;
import hunt.http.codec.websocket.frame.Frame;

import hunt.http.HttpConnection;

import hunt.Functions;
import hunt.collection.ByteBuffer;

// https://stackoverflow.com/questions/4725241/whats-the-difference-between-event-listeners-handlers-in-java

/**
 * 
 */
interface WebSocketMessageHandler {

    void onOpen(WebSocketConnection connection);

    void onText(string text, WebSocketConnection connection);

    void onError(Exception exception, WebSocketConnection connection);    
}

deprecated("Using AbstractWebSocketListener instead.")
alias AbstractWebSocketBuilder = AbstractWebSocketListener;

/**
 * 
 */
abstract class AbstractWebSocketListener  {

    protected Action2!(string, WebSocketConnection) _textHandler;
    protected Action2!(ByteBuffer, WebSocketConnection) _dataHandler;
    protected Action2!(Throwable, WebSocketConnection) _errorHandler;

    AbstractWebSocketListener onText(Action2!(string, WebSocketConnection) handler) {
        this._textHandler = handler;
        return this;
    }

    AbstractWebSocketListener onData(Action2!(ByteBuffer, WebSocketConnection) handler) {
        this._dataHandler = handler;
        return this;
    }

    AbstractWebSocketListener onError(Action2!(Throwable, WebSocketConnection) handler) {
        this._errorHandler = handler;
        return this;
    }

    void onFrame(Frame frame, WebSocketConnection connection) {
        switch (frame.getType()) {
            case FrameType.TEXT:
                if(_textHandler !is null)
                    _textHandler((cast(DataFrame) frame).getPayloadAsUTF8(), connection);
                break;
            case FrameType.CONTINUATION:
            case FrameType.BINARY:
                if(_dataHandler !is null)
                    _dataHandler(frame.getPayload(), connection);
                break;

            default: break;
        }
    }

    void onError(Throwable t, WebSocketConnection connection) {
        if(_errorHandler !is null)
            _errorHandler(t, connection);
    }
}
