module hunt.http.AbstractHttpConnection;

import hunt.http.HttpConnection;
import hunt.http.HttpVersion;

import hunt.http.HttpConnectionType;

import hunt.collection.ByteBuffer;
import hunt.net.AbstractConnection;
import hunt.net.Connection;
import hunt.net.secure.SecureSession;
import hunt.net.Exceptions;
import hunt.net.OutputEntry;

import hunt.Exceptions;
import hunt.Functions;

abstract class AbstractHttpConnection : HttpConnection { // AbstractConnection,

    // protected SecureSession secureSession;
    Connection tcpSession;
    protected HttpVersion httpVersion;
    // protected Object attachment;
    // protected ConnectionEvent!HttpConnection connectionEvent;

    this(Connection tcpSession, HttpVersion httpVersion) {
        // super(secureSession, tcpSession);
        this.tcpSession = tcpSession;
        this.httpVersion = httpVersion;
        // connectionEvent = new ConnectionEvent!(HttpConnection)(this);
    }

    alias tcpSession this ;

    int getId() {
        return tcpSession.getId();
    }

    Connection getTcpConnection() {
        return tcpSession;
    }

    // override
    // Object getAttachment() {
    //     return tcpSession.getAttachment();
    // }

    // override
    // void attachObject(Object attachment) {
    //     tcpSession.attachObject(attachment);
    // }

    abstract HttpConnectionType getConnectionType();

    override HttpVersion getHttpVersion() {
        return httpVersion;
    }

    // override
    // bool isSecured() {
    //     return tcpSession.isSecured();
    // }

    // override
    // HttpConnection onClose(Action1!HttpConnection closedListener) {
    //     return connectionEvent.onClose(closedListener);
    // }

    // override
    // HttpConnection onException(Action2!(HttpConnection, Exception) exceptionListener) {
    //     return connectionEvent.onException(exceptionListener);
    // }

    void notifyClose() {
        implementationMissing(false);
        // connectionEvent.notifyClose();
    }

    void notifyException(Exception t) {
        implementationMissing(false);
        // connectionEvent.notifyException(t);
    }

    ///
    void close() {
        tcpSession.close();
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
