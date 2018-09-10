module hunt.http.codec.http.stream.HttpTunnelConnection;

import hunt.http.codec.http.stream.HttpConnection;

// import hunt.net.buffer.FileRegion;
import hunt.util.functional;

import hunt.container.ByteBuffer;
import hunt.container.Collection;

/**
 * 
 */
interface HttpTunnelConnection  { // :HttpConnection

    void write(ByteBuffer byteBuffer, Callback callback);

    void write(ByteBuffer[] buffers, Callback callback);

    void write(Collection!ByteBuffer buffers, Callback callback);

    // void write(FileRegion file, Callback callback);

    void receive(Action1!ByteBuffer content);

}
