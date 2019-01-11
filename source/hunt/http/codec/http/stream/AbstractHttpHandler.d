module hunt.http.codec.http.stream.AbstractHttpHandler;

import hunt.http.codec.http.stream.Http2Configuration;
import hunt.http.codec.http.stream.AbstractHttpConnection;

// import hunt.http.codec.websocket.stream.impl.WebSocketConnectionImpl;
import hunt.net.Handler;
import hunt.net.Session;

import hunt.Exceptions;
import hunt.logging;

import std.exception;

abstract class AbstractHttpHandler : Handler {

    protected Http2Configuration config;

    this(Http2Configuration config) {
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
            
            AbstractHttpConnection httpConnection = cast(AbstractHttpConnection) attachment;
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
        version(HUNT_DEBUG) 
            tracef("The HTTP handler received the session %s closed event.", session.getSessionId());
        Object attachment = session.getAttachment();
        if (attachment is null) {
            return;
        }
        if (typeid(attachment) == typeid(AbstractHttpConnection)) {
            try {
                AbstractHttpConnection httpConnection = cast(AbstractHttpConnection) attachment;
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
