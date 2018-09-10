module hunt.http.client.http.ClientHttp2SessionListener;

import hunt.http.client.http.Http2ClientConnection;

import hunt.http.codec.http.frame.GoAwayFrame;
import hunt.http.codec.http.frame.ResetFrame;
import hunt.http.codec.http.stream.HttpConnection;
import hunt.http.codec.http.stream.Session;
import hunt.io;
import hunt.logging;


/**
 * 
 */
class ClientHttp2SessionListener : Session.Listener.Adapter {

    private Http2ClientConnection connection;

    this() {
    }

    this(Http2ClientConnection connection) {
        this.connection = connection;
    }

    Http2ClientConnection getConnection() {
        return connection;
    }

    void setConnection(Http2ClientConnection connection) {
        this.connection = connection;
    }

    override
    void onClose(Session session, GoAwayFrame frame) {
        warningf("Client received the GoAwayFrame -> %s", frame.toString());
        if(connection !is null)
            IO.close(connection);
    }

    override
    void onFailure(Session session, Exception failure) {
        errorf("Client failure: " ~ session.toString(), failure);
        if(connection !is null)
            IO.close(connection);
    }

    override
    void onReset(Session session, ResetFrame frame) {
        warningf("Client received ResetFrame %s", frame.toString());
        if(connection !is null)
            IO.close(connection);
    }
}
