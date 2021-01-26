module hunt.http.HttpConnection;

import hunt.http.HttpConnection;
import hunt.http.HttpOptions;
import hunt.http.HttpVersion;

import hunt.io.ByteBuffer;
import hunt.concurrency.ScheduledThreadPoolExecutor;
import hunt.Exceptions;
import hunt.Functions;
import hunt.logging.ConsoleLogger;
import hunt.net.AbstractConnection;
import hunt.net.Connection;
import hunt.net.Exceptions;
import hunt.net.secure.SecureSession;
import hunt.util.Common;

import std.exception;
import std.socket;

/**
 * 
 */
enum HttpConnectionType {
    HTTP1, HTTP2, HTTP_TUNNEL, WEB_SOCKET
}

interface HttpConnection : Closeable { // : Connection 

    enum string NAME = typeof(this).stringof;

    int getId();

    Connection getTcpConnection();

    HttpVersion getHttpVersion();

    Address getLocalAddress();

    Address getRemoteAddress();

    HttpConnection onClose(Action1!(HttpConnection) handler);

    HttpConnection onException(Action2!(HttpConnection, Exception) handler);


    /**
     * Returns the value of the user-defined attribute of this connection.
     *
     * @param key the key of the attribute
     * @return <tt>null</tt> if there is no attribute with the specified key
     */
    Object getAttribute(string key);
    
    /**
     * Sets a user-defined attribute.
     *
     * @param key the key of the attribute
     * @param value the value of the attribute
     */
    void setAttribute(string key, Object value);

    /**
     * Removes a user-defined attribute with the specified key.
     *
     * @param key The key of the attribute we want to remove
     * @return The old value of the attribute.  <tt>null</tt> if not found.
     */
    Object removeAttribute(string key);

    /**
     * @param key The key of the attribute we are looking for in the connection 
     * @return <tt>true</tt> if this connection contains the attribute with
     * the specified <tt>key</tt>.
     */
    bool containsAttribute(string key);
}


/**
 * 
 */
abstract class AbstractHttpConnection : HttpConnection { 
    
    protected ScheduledThreadPoolExecutor executor;

    protected Connection _tcpSession;
    protected HttpVersion _httpVersion;
    // protected ConnectionEvent!HttpConnection connectionEvent;
    protected Action1!HttpConnection _closeHandler;
    protected Action2!(HttpConnection, Exception) _exceptionHandler;

    this(Connection tcpSession, HttpVersion httpVersion) {
        this._tcpSession = tcpSession;
        this._httpVersion = httpVersion;
        // connectionEvent = new ConnectionEvent!(HttpConnection)(this);
    }

    // alias tcpSession this ;
    Connection getTcpConnection() {
        return _tcpSession;
    }

    abstract HttpConnectionType getConnectionType();


    Address getLocalAddress() {
        return _tcpSession.getLocalAddress();
    }

    Address getRemoteAddress() {
        return _tcpSession.getRemoteAddress();
    }

    override HttpVersion getHttpVersion() {
        return _httpVersion;
    }

    int getId() {
        return _tcpSession.getId();
    }

    bool isSecured() {
        return _tcpSession.isSecured();
    }

    void setAttribute(string key, Object value) {
        _tcpSession.setAttribute(key, value);
    }
    
    Object getAttribute(string key) {
        return _tcpSession.getAttribute(key);
    }
    
    Object removeAttribute(string key) {
        return _tcpSession.removeAttribute(key);
    }

    bool containsAttribute(string key) {
        return _tcpSession.containsAttribute(key);
    }

    override
    HttpConnection onClose(Action1!HttpConnection handler) {
        _closeHandler = handler;
        return this;
        // return connectionEvent.onClose(closedListener);
    }

    override
    HttpConnection onException(Action2!(HttpConnection, Exception) handler) {
        _exceptionHandler = handler;
        return this;
        // return connectionEvent.onException(exceptionListener);
    }

    void notifyClose() {
        // implementationMissing(false);
        // connectionEvent.notifyClose();
        if(_closeHandler !is null) {
            _closeHandler(this);
        }
    }

    void notifyException(Exception t) {
        // implementationMissing(false);
        if(_exceptionHandler !is null) {
            _exceptionHandler(this, t);
        }
        // connectionEvent.notifyException(t);
    }

    ///
    void close() {
        _tcpSession.close();
    }



    // ByteBuffer decrypt(ByteBuffer buffer) {

    //     implementationMissing(false);
    //     return null;
        
    //     // if (isEncrypted()) {
    //     //     try {
    //     //         return secureSession.read(buffer);
    //     //     } catch (IOException e) {
    //     //         throw new SecureNetException("decrypt exception", e);
    //     //     }
    //     // } else {
    //     //     return null;
    //     // }
    // }

    // void encrypt(ByteBufferOutputEntry entry) {
    //     implementationMissing(false);
    //     // encrypt!(ByteBuffer)(entry, (buffers, callback) {
    //     //     try {
    //     //         secureSession.write(buffers, callback);
    //     //     } catch (IOException e) {
    //     //         throw new SecureNetException("encrypt exception", e);
    //     //     }
    //     // });
    // }

    // void encrypt(ByteBufferArrayOutputEntry entry) {
    //     encrypt(entry, (buffers, callback) {
    //         try {
    //             secureSession.write(buffers, callback);
    //         } catch (IOException e) {
    //             throw new SecureNetException("encrypt exception", e);
    //         }
    //     });
    // }

    // void encrypt(ByteBuffer buffer) {
    //     // try {
    //     //     secureSession.write(buffer, Callback.NOOP);
    //     // } catch (IOException e) {
    //     //     errorf(e.toString());
    //     //     throw new SecureNetException("encrypt exception", e);
    //     // }

    //     implementationMissing(false);
    // }

    // void encrypt(ByteBuffer[] buffers) {
    //     // try {
    //     //     secureSession.write(buffers, Callback.NOOP);
    //     // } catch (IOException e) {
    //     //     throw new SecureNetException("encrypt exception", e);
    //     // }
    //     implementationMissing(false);
    // }

    // private void encrypt(T)(OutputEntry!T entry, Action2!(T, Callback) et) {

    //     implementationMissing(false);
    //     // if (isEncrypted()) {
    //     //     et(entry.getData(), entry.getCallback());
    //     // }
    // }

}
 

/**
 * 
 */
abstract class HttpConnectionHandler : NetConnectionHandlerAdapter {

    // override
    // DataHandleStatus messageReceived(Connection connection, Object message) {
    //     implementationMissing(false);
    //     return DataHandleStatus.Done;
    // }

    override
    void exceptionCaught(Connection connection, Throwable t) {
        try {
            version(HUNT_DEBUG) warningf("HTTP handler exception: %s", t.toString());
            if(connection is null) {
                version(HUNT_DEBUG) warning("Connection is null.");
            } else {
                Object attachment = connection.getAttribute(HttpConnection.NAME); 
                if (attachment is null) {
                    version(HUNT_DEBUG) warningf("attachment is null");
                } else {
                    AbstractHttpConnection httpConnection = cast(AbstractHttpConnection) attachment;
                    if (httpConnection !is null ) {
                        Exception ex = cast(Exception)t;
                        if(ex is null && t !is null) {
                            warningf("Can't handle a exception. Exception: %s", t.msg);
                        }
                        httpConnection.notifyException(ex);
                    } 
                }
            }
        } finally {
            if(connection !is null)
                connection.close();
        }
    }

    override
    void connectionClosed(Connection connection) {
        version(HUNT_DEBUG) {
            infof("Connection %d closed event. Remote host: %s", 
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

    // override
    // void connectionOpened(Connection connection) {
    //     implementationMissing(false);
    // }

    // override
    // void failedOpeningConnection(int connectionId, Throwable t) { 
    //     errorf("Failed to open a http connection %d, reason: <%s>", connectionId, t.msg);
    //     super.failedOpeningConnection(connectionId, t);
    // }

    override
    void failedAcceptingConnection(int connectionId, Throwable t) { implementationMissing(false); }
}
