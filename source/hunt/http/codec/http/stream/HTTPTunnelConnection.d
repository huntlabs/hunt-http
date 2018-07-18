module hunt.http.codec.http.stream.HTTPTunnelConnection;

import hunt.http.codec.http.stream.HTTPConnection;

// import hunt.net.buffer.FileRegion;
import hunt.util.functional;

import hunt.container.ByteBuffer;
import hunt.container.Collection;

/**
 * 
 */
interface HTTPTunnelConnection  { // :HTTPConnection

    void write(ByteBuffer byteBuffer, Callback callback);

    void write(ByteBuffer[] buffers, Callback callback);

    void write(Collection!ByteBuffer buffers, Callback callback);

    // void write(FileRegion file, Callback callback);

    void receive(Action1!ByteBuffer content);

}
