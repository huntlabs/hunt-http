module hunt.http.codec.http.stream.AbstractHTTPHandler;

import hunt.http.codec.http.stream.HTTP2Configuration;
import hunt.http.codec.http.stream.AbstractHTTPConnection;

// import hunt.http.codec.websocket.stream.impl.WebSocketConnectionImpl;
import hunt.net.Handler;
import hunt.net.Session;

import hunt.util.exception;
import hunt.logging;

import std.exception;

abstract class AbstractHTTPHandler : Handler {

    protected HTTP2Configuration config;

    this(HTTP2Configuration config) {
        this.config = config;
    }

    override
    void messageReceived(Session session, Object message) {
        implementationMissing(false);
    }

    override
    void exceptionCaught(Session session, Exception t) {
        try {
            errorf("HTTP handler exception: %s", t.toString());
            Object attachment = session.getAttachment();
            if (attachment is null) {
                return;
            }
            
            AbstractHTTPConnection httpConnection = cast(AbstractHTTPConnection) attachment;
            if (httpConnection !is null ) {
                try {
                    httpConnection.notifyException(t);
                } catch (Exception e) {
                    errorf("The http connection exception listener error: %s", e.message);
                }
            } 
            // else if (typeid(attachment) == typeid(WebSocketConnectionImpl)) {
            //     try {
            //         WebSocketConnectionImpl webSocketConnection = cast(WebSocketConnectionImpl) attachment;
            //         webSocketConnection.notifyException(t);
            //     } catch (Exception e) {
            //         errorf("The websocket connection exception listener error", e);
            //     }
            // }
        } finally {
            session.close();
        }
    }

    override
    void sessionClosed(Session session) {
        info("The HTTP handler received the session %s closed event.", session.getSessionId());
        Object attachment = session.getAttachment();
        if (attachment is null) {
            return;
        }
        if (typeid(attachment) == typeid(AbstractHTTPConnection)) {
            try {
                AbstractHTTPConnection httpConnection = cast(AbstractHTTPConnection) attachment;
                httpConnection.notifyClose();
            } catch (Exception e) {
                errorf("The http2 connection close exception", e);
            }
        } 
        // else if (typeid(attachment) == typeid(WebSocketConnectionImpl)) {
        //     try {
        //         WebSocketConnectionImpl webSocketConnection = cast(WebSocketConnectionImpl) attachment;
        //         webSocketConnection.notifyClose();
        //     } catch (Exception e) {
        //         errorf("The websocket connection close exception", e);
        //     }
        // }
    }

}
