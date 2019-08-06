module hunt.http.server.Http1ServerTunnelConnection;

import hunt.http.HttpVersion;
import hunt.http.AbstractHttpConnection;
import hunt.http.codec.http.stream.HttpTunnelConnection;

import hunt.http.HttpConnectionType;
import hunt.net.secure.SecureSession;
import hunt.net.Connection;
// import hunt.net.buffer.FileRegion;

import hunt.Functions;
import hunt.util.Common;

import hunt.collection.ByteBuffer;
import hunt.collection.Collection;

/**
 * 
 */
class Http1ServerTunnelConnection : AbstractHttpConnection , HttpTunnelConnection {

    Action1!ByteBuffer content;

    this(Connection tcpSession, HttpVersion httpVersion) {
        super(tcpSession, httpVersion);
    }

    override
    void write(ByteBuffer byteBuffer, Callback callback) {
        tcpSession.write(byteBuffer); // , callback
    }

    // override
    // void write(ByteBuffer[] buffers, Callback callback) {
    //     tcpSession.write(buffers, callback);
    // }

    // override
    // void write(Collection!ByteBuffer buffers, Callback callback) {
    //     tcpSession.write(buffers, callback);
    // }

    // override
    // void write(FileRegion file, Callback callback) {
    //     tcpSession.write(file, callback);
    // }

    override
    void receive(Action1!ByteBuffer content) {
        this.content = content;
    }

    override
    HttpConnectionType getConnectionType() {
        return HttpConnectionType.HTTP_TUNNEL;
    }
}
