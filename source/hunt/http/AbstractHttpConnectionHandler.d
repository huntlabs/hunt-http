module hunt.http.AbstractHttpConnectionHandler;

import hunt.http.AbstractHttpConnection;
import hunt.http.HttpOptions;
import hunt.http.HttpConnection;

import hunt.http.codec.websocket.stream.WebSocketConnectionImpl;
import hunt.net.Connection;

import hunt.Exceptions;
import hunt.logging;

import std.exception;

alias AbstractHttpHandler = AbstractHttpConnectionHandler;

abstract class AbstractHttpConnectionHandler : ConnectionEventHandler {

    protected HttpOptions config;

    this(HttpOptions config) {
        this.config = config;
    }

    override
    void messageReceived(Connection connection, Object message) {
        implementationMissing(false);
    }

    override
    void exceptionCaught(Connection connection, Exception t) {
        try {
            errorf("HTTP handler exception: %s", t.toString());
            Object attachment = connection.getAttribute(HttpConnection.NAME); // connection.getAttachment();
            if (attachment is null) {
                version(HUNT_DEBUG) warningf("attachment is null");
            } else {
                AbstractHttpConnection httpConnection = cast(AbstractHttpConnection) attachment;
                if (httpConnection !is null ) {
                    try {
                        httpConnection.notifyException(t);
                    } catch (Exception e) {
                        errorf("The http connection exception listener error: %s", e.message);
                    }
                } else { 
                    WebSocketConnectionImpl webSocketConnection = cast(WebSocketConnectionImpl) attachment;
                    if (webSocketConnection !is null) {
                        try {
                            webSocketConnection.notifyException(t);
                        } catch (Exception e) {
                            errorf("The websocket connection exception listener error", e);
                        }
                    }
                }
            }
        } finally {
            connection.close();
        }
    }

    override
    void connectionClosed(Connection connection) {
        version(HUNT_HTTP_DEBUG) 
            tracef("The HTTP handler received the connection %s closed event.", connection.getId());
        Object attachment = connection.getAttribute(HttpConnection.NAME); // connection.getAttachment();
        if (attachment is null) {
            version(HUNT_HTTP_DEBUG) warningf("no connection attached");
        } else {
            version(HUNT_HTTP_DEBUG) tracef("attached connection: %s", typeid(attachment).name);
            AbstractHttpConnection httpConnection = cast(AbstractHttpConnection) attachment;
            if (httpConnection !is null) {
                try {
                    httpConnection.notifyClose();
                } catch (Exception e) {
                    errorf("The http connection close exception", e);
                }
            } 
        }
    }

}
