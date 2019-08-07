module hunt.http.codec.http.stream.AbstractHttpHandler;

import hunt.http.HttpOptions;
import hunt.http.AbstractHttpConnection;
import hunt.http.HttpConnection;

import hunt.net.Connection;

import hunt.Exceptions;
import hunt.logging;

import std.exception;

alias AbstractHttpHandler = AbstractHttpConnectionHandler;

abstract class AbstractHttpConnectionHandler : ConnectionEventHandler {

    protected HttpConfiguration config;

    this(HttpConfiguration config) {
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
            version(HUNT_HTTP_DEBUG) warningf("attachment is null");
        } else {
            version(HUNT_HTTP_DEBUG) tracef("attachment is %s", typeid(attachment).name);
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
