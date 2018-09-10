module hunt.http.codec.http.stream.HttpConnection;

import hunt.http.codec.http.model.HttpVersion;

import hunt.net.ConnectionExtInfo;
import hunt.net.Connection;

import hunt.util.functional;


interface HttpConnection : Connection, ConnectionExtInfo {

    HttpVersion getHttpVersion();

    HttpConnection onClose(Action1!(HttpConnection) closedCallback);

    HttpConnection onException(Action2!(HttpConnection, Exception) exceptionCallback);

}