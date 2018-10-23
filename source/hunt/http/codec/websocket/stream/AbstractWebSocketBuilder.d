module hunt.http.codec.websocket.stream.AbstractWebSocketBuilder;

import hunt.http.codec.websocket.stream.WebSocketConnection;

import hunt.http.codec.websocket.frame.DataFrame;
import hunt.http.codec.websocket.frame.Frame;
import hunt.lang.common;

import hunt.container.ByteBuffer;

/**
 * 
 */
abstract class AbstractWebSocketBuilder {

    protected Action2!(string, WebSocketConnection) _textHandler;
    protected Action2!(ByteBuffer, WebSocketConnection) _dataHandler;
    protected Action2!(Throwable, WebSocketConnection) _errorHandler;

    AbstractWebSocketBuilder onText(Action2!(string, WebSocketConnection) handler) {
        this._textHandler = handler;
        return this;
    }

    AbstractWebSocketBuilder onData(Action2!(ByteBuffer, WebSocketConnection) handler) {
        this._dataHandler = handler;
        return this;
    }

    AbstractWebSocketBuilder onError(Action2!(Throwable, WebSocketConnection) handler) {
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
