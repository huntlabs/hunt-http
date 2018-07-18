module hunt.http.codec.http.stream.HTTPOutputStream;

import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.model.MetaData;


import hunt.container;
import hunt.util.io;
import hunt.util.exception;

import kiss.logger;
import std.conv;

abstract class HTTPOutputStream :OutputStream {

    protected bool clientMode;
    protected MetaData info;
    protected bool closed;
    protected bool committed;

    this(MetaData info, bool clientMode) {
        this.info = info;
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
    //             info.getFields().put(HttpHeader.CONTENT_LENGTH, contentLength.to!string);
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
                info.getFields().put(HttpHeader.CONTENT_LENGTH, contentLength.to!string);
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
