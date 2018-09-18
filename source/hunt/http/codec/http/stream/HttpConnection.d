module hunt.http.codec.http.stream.HttpConnection;

import hunt.http.codec.http.model.HttpVersion;
import hunt.net.Connection;
import hunt.util.functional;


interface HttpConnection : Connection {

    HttpVersion getHttpVersion();

    HttpConnection onClose(Action1!(HttpConnection) closedCallback);

    HttpConnection onException(Action2!(HttpConnection, Exception) exceptionCallback);

}