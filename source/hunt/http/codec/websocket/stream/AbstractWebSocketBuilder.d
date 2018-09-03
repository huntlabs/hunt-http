module hunt.http.codec.websocket.stream;

import hunt.http.codec.websocket.frame.DataFrame;
import hunt.http.codec.websocket.frame.Frame;
import hunt.http.utils.function.Action2;

import hunt.container.ByteBuffer;
import java.util.Optional;

/**
 * 
 */
abstract class AbstractWebSocketBuilder {

    protected Action2<string, WebSocketConnection> onText;
    protected Action2<ByteBuffer, WebSocketConnection> onData;
    protected Action2<Throwable, WebSocketConnection> onError;

    AbstractWebSocketBuilder onText(Action2<string, WebSocketConnection> onText) {
        this.onText = onText;
        return this;
    }

    AbstractWebSocketBuilder onData(Action2<ByteBuffer, WebSocketConnection> onData) {
        this.onData = onData;
        return this;
    }

    AbstractWebSocketBuilder onError(Action2<Throwable, WebSocketConnection> onError) {
        this.onError = onError;
        return this;
    }

    void onFrame(Frame frame, WebSocketConnection connection) {
        switch (frame.getType()) {
            case TEXT:
                Optional.ofNullable(onText).ifPresent(t -> t.call(((DataFrame) frame).getPayloadAsUTF8(), connection));
                break;
            case CONTINUATION:
            case BINARY:
                Optional.ofNullable(onData).ifPresent(d -> d.call(frame.getPayload(), connection));
                break;
        }
    }

    void onError(Throwable t, WebSocketConnection connection) {
        Optional.ofNullable(onError).ifPresent(e -> e.call(t, connection));
    }
}
