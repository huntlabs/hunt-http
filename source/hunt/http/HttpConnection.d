module hunt.http.HttpConnection;

import hunt.http.HttpVersion;
import hunt.net.Connection;
import hunt.Functions;
import hunt.util.Common;


interface HttpConnection : Closeable { // : Connection 

    enum string NAME = typeof(this).stringof;

    int getId();

    Connection getTcpConnection();

    HttpVersion getHttpVersion();

    // HttpConnection onClose(Action1!(HttpConnection) closedCallback);

    // HttpConnection onException(Action2!(HttpConnection, Exception) exceptionCallback);

}