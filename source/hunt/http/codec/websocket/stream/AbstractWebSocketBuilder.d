module hunt.http.codec.websocket.stream;

import hunt.http.codec.websocket.stream.WebSocketConnection;

import hunt.http.codec.websocket.frame.DataFrame;
import hunt.http.codec.websocket.frame.Frame;
import hunt.util.functional;

import hunt.container.ByteBuffer;

/**
 * 
 */
abstract class AbstractWebSocketBuilder {

    protected Action2!(string, WebSocketConnection) _onText;
    protected Action2!(ByteBuffer, WebSocketConnection) _onData;
    protected Action2!(Throwable, WebSocketConnection) _onError;

    AbstractWebSocketBuilder onText(Action2!(string, WebSocketConnection) onText) {
        this._onText = onText;
        return this;
    }

    AbstractWebSocketBuilder onData(Action2!(ByteBuffer, WebSocketConnection) onData) {
        this._onData = onData;
        return this;
    }

    AbstractWebSocketBuilder onError(Action2!(Throwable, WebSocketConnection) onError) {
        this._onError = onError;
        return this;
    }

    void onFrame(Frame frame, WebSocketConnection connection) {
        switch (frame.getType()) {
            case TEXT:
                if(_onText !is null)
                    _onText((cast(DataFrame) frame).getPayloadAsUTF8(), connection)；
                // Optional.ofNullable(onText).ifPresent(t -> t.call(((DataFrame) frame).getPayloadAsUTF8(), connection));
                break;
            case CONTINUATION:
            case BINARY:
                if(_onData !is null)
                    _onData(frame.getPayload(), connection);
                // Optional.ofNullable(onData).ifPresent(d -> d.call(frame.getPayload(), connection));
                break;
        }
    }

    void onError(Throwable t, WebSocketConnection connection) {
        if(_onError !is null)
            _onError(t, connection);
        // Optional.ofNullable(onError).ifPresent(e -> e.call(t, connection));
    }
}
