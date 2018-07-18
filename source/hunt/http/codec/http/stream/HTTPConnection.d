module hunt.http.codec.http.stream.HTTPConnection;

import hunt.http.codec.http.model.HttpVersion;

import hunt.net.ConnectionExtInfo;
import hunt.net.Connection;

import hunt.util.functional;


interface HTTPConnection : Connection, ConnectionExtInfo {

    HttpVersion getHttpVersion();

    HTTPConnection onClose(Action1!(HTTPConnection) closedCallback);

    HTTPConnection onException(Action2!(HTTPConnection, Exception) exceptionCallback);

}