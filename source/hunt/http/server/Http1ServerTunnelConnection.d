module hunt.http.server.Http1ServerTunnelConnection;

import hunt.http.codec.http.model.HttpVersion;
import hunt.http.codec.http.stream.AbstractHttpConnection;
import hunt.http.codec.http.stream.HttpTunnelConnection;

import hunt.net.ConnectionType;
import hunt.net.secure.SecureSession;
import hunt.net.Session;
// import hunt.net.buffer.FileRegion;

import hunt.lang.common;
import hunt.util.functional;

import hunt.container.ByteBuffer;
import hunt.container.Collection;

/**
 * 
 */
class Http1ServerTunnelConnection : AbstractHttpConnection , HttpTunnelConnection {

    Action1!ByteBuffer content;

    this(SecureSession secureSession, TcpSession tcpSession, HttpVersion httpVersion) {
        super(secureSession, tcpSession, httpVersion);
    }

    override
    void write(ByteBuffer byteBuffer, Callback callback) {
        tcpSession.write(byteBuffer, callback);
    }

    override
    void write(ByteBuffer[] buffers, Callback callback) {
        tcpSession.write(buffers, callback);
    }

    override
    void write(Collection!ByteBuffer buffers, Callback callback) {
        tcpSession.write(buffers, callback);
    }

    // override
    // void write(FileRegion file, Callback callback) {
    //     tcpSession.write(file, callback);
    // }

    override
    void receive(Action1!ByteBuffer content) {
        this.content = content;
    }

    // override
    ConnectionType getConnectionType() {
        return ConnectionType.HTTP_TUNNEL;
    }
}
