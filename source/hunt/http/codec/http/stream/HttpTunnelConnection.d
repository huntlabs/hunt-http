module hunt.http.codec.http.stream.HttpTunnelConnection;

import hunt.http.codec.http.stream.HttpConnection;

// import hunt.net.buffer.FileRegion;
import hunt.Functions;
import hunt.util.Common;

import hunt.collection.ByteBuffer;
import hunt.collection.Collection;

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
