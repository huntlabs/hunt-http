module hunt.http.codec.http.stream.HttpOutputStream;

import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.model.MetaData;

import hunt.collection;
import hunt.io;
import hunt.Exceptions;
import hunt.logging;
import std.conv;

abstract class HttpOutputStream : OutputStream {

    protected bool clientMode;
    protected MetaData metaData;
    protected bool closed;
    protected bool committed;

    this(MetaData metaData, bool clientMode) {
        this.metaData = metaData;
        this.clientMode = clientMode;
    }

    bool isClosed() {
        return closed;
    }

    bool isCommitted() {
        return committed;
    }

    override
    void write(int b) {
        // byte* ptr = cast(byte*)&b;
        // write(ptr[0..int.sizeof]);

        write(cast(byte[]) [cast (byte) b]);
    }

    override
    void write(byte[] array, int offset, int length) {
        assert(array !is null, "The data must be not null");
        write(ByteBuffer.wrap(array, offset, length));
    }

    alias write = OutputStream.write;

    // void writeWithContentLength(Collection!ByteBuffer data) {
    //     if (closed) {
    //         return;
    //     }

    //     try {
    //         if (!committed) {
    //             long contentLength = BufferUtils.remaining(data);
    //             metaData.getFields().put(HttpHeader.CONTENT_LENGTH, contentLength.to!string);
    //         }
    //         foreach (ByteBuffer buf ; data) {
    //             write(buf);
    //         }
    //     } finally {
    //         close();
    //     }
    // }

    void writeWithContentLength(ByteBuffer[] data) {
        if (closed) {
            return;
        }

        try {
            if (!committed) {
                long contentLength = BufferUtils.remaining(data);
                metaData.getFields().put(HttpHeader.CONTENT_LENGTH, contentLength.to!string);
            }
            foreach (ByteBuffer buf ; data) {
                write(buf);
            }
        } finally {
            close();
        }        
    }

    void writeWithContentLength(ByteBuffer data) {
        writeWithContentLength([data]);
    }

    abstract void commit() ;

    abstract void write(ByteBuffer data) ;
}
