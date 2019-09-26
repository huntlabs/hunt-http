module hunt.http.AbstractHttpConnection;

import hunt.http.HttpConnection;
import hunt.http.HttpVersion;

import hunt.http.HttpConnectionType;

import hunt.collection.ByteBuffer;
import hunt.net.AbstractConnection;
import hunt.net.Connection;
import hunt.net.secure.SecureSession;
import hunt.net.Exceptions;

import hunt.Exceptions;
import hunt.Functions;
import std.socket;

/**
 * 
 */
abstract class AbstractHttpConnection : HttpConnection { 

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
