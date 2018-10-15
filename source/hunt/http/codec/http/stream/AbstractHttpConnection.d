module hunt.http.codec.http.stream.AbstractHttpConnection;

import hunt.http.codec.http.stream.HttpConnection;

import hunt.http.codec.http.model.HttpVersion;

import hunt.net.AbstractConnection;
import hunt.net.ConnectionEvent;
import hunt.net.secure.SecureSession;
import hunt.net.Session;

import hunt.lang.common;

abstract class AbstractHttpConnection :AbstractConnection, HttpConnection {

    protected HttpVersion httpVersion;
    protected  Object attachment;
    protected ConnectionEvent!HttpConnection connectionEvent;

    this(SecureSession secureSession, Session tcpSession, HttpVersion httpVersion) {
        super(secureSession, tcpSession);
        this.httpVersion = httpVersion;
        connectionEvent = new ConnectionEvent!(HttpConnection)(this);
    }

    override
    Object getAttachment() {
        return attachment;
    }

    override
    void setAttachment(Object attachment) {
        this.attachment = attachment;
    }

    override
    HttpVersion getHttpVersion() {
        return httpVersion;
    }

    override
    bool isEncrypted() {
        return secureSession !is null;
    }

    override
    HttpConnection onClose(Action1!HttpConnection closedListener) {
        return connectionEvent.onClose(closedListener);
    }

    override
    HttpConnection onException(Action2!(HttpConnection, Exception) exceptionListener) {
        return connectionEvent.onException(exceptionListener);
    }

    void notifyClose() {
        connectionEvent.notifyClose();
    }

    void notifyException(Exception t) {
        connectionEvent.notifyException(t);
    }
}
