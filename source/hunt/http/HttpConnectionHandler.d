module hunt.http.HttpConnectionHandler;

import hunt.http.AbstractHttpConnection;
import hunt.http.HttpOptions;
import hunt.http.HttpConnection;
import hunt.net.Connection;

import hunt.Exceptions;
import hunt.logging;

import std.exception;

deprecated("Using HttpConnectionHandler instead.")
alias AbstractHttpHandler = HttpConnectionHandler;

/**
*/
abstract class HttpConnectionHandler : ConnectionEventHandler {

    protected HttpOptions config;

    this(HttpOptions config) {
        this.config = config;
    }

    override
    void messageReceived(Connection connection, Object message) {
        implementationMissing(false);
    }

    override
    void exceptionCaught(Connection connection, Throwable t) {
        try {
            version(HUNT_DEBUG) warningf("HTTP handler exception: %s", t.toString());
            Object attachment = connection.getAttribute(HttpConnection.NAME); 
            if (attachment is null) {
                version(HUNT_DEBUG) warningf("attachment is null");
            } else {
                AbstractHttpConnection httpConnection = cast(AbstractHttpConnection) attachment;
                if (httpConnection !is null ) {
                    try {
                        Exception ex = cast(Exception)t;
                        if(ex is null && t !is null) {
                            warningf("Can't handle a exception. Exception: %s", t.msg);
                        }
                        httpConnection.notifyException(ex);
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
        version(HUNT_HTTP_DEBUG) {
            infof("Connection %s closed event. Remote host: %s", 
                connection.getId(), connection.getRemoteAddress());
        }

        Object attachment = connection.getAttribute(HttpConnection.NAME);
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

    override
    void connectionOpened(Connection connection) {
        implementationMissing(false);
    }

    override
    void failedOpeningConnection(int connectionId, Throwable t) { implementationMissing(false); }

    override
    void failedAcceptingConnection(int connectionId, Throwable t) { implementationMissing(false); }
}
