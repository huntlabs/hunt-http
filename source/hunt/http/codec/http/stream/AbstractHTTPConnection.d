module hunt.http.codec.http.stream.AbstractHTTPConnection;

import hunt.http.codec.http.stream.HTTPConnection;

import hunt.http.codec.http.model.HttpVersion;

import hunt.net.AbstractConnection;
import hunt.net.ConnectionEvent;
import hunt.net.SecureSession;
import hunt.net.Session;

import hunt.util.functional;

abstract class AbstractHTTPConnection :AbstractConnection, HTTPConnection {

    protected HttpVersion httpVersion;
    protected  Object attachment;
    protected ConnectionEvent!HTTPConnection connectionEvent;

    this(SecureSession secureSession, Session tcpSession, HttpVersion httpVersion) {
        super(secureSession, tcpSession);
        this.httpVersion = httpVersion;
        connectionEvent = new ConnectionEvent!(HTTPConnection)(this);
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
    HTTPConnection onClose(Action1!HTTPConnection closedListener) {
        return connectionEvent.onClose(closedListener);
    }

    override
    HTTPConnection onException(Action2!(HTTPConnection, Exception) exceptionListener) {
        return connectionEvent.onException(exceptionListener);
    }

    void notifyClose() {
        connectionEvent.notifyClose();
    }

    void notifyException(Exception t) {
        connectionEvent.notifyException(t);
    }
}
