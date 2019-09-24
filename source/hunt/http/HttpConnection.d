module hunt.http.HttpConnection;

import hunt.http.HttpVersion;
import hunt.net.Connection;
import hunt.Functions;
import hunt.util.Common;

import std.socket;


interface HttpConnection : Closeable { // : Connection 

    enum string NAME = typeof(this).stringof;

    int getId();

    Connection getTcpConnection();

    HttpVersion getHttpVersion();

    Address getLocalAddress();

    Address getRemoteAddress();

    // HttpConnection onClose(Action1!(HttpConnection) closedCallback);

    // HttpConnection onException(Action2!(HttpConnection, Exception) exceptionCallback);

}