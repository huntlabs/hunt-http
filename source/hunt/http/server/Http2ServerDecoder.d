module hunt.http.server.Http2ServerDecoder;

import hunt.http.server.Http2ServerConnection;
import hunt.http.HttpConnection;

import hunt.net.codec.Decoder;
import hunt.net.Connection;
import hunt.logging;


import hunt.collection.ByteBuffer;

class Http2ServerDecoder : DecoderChain {    

    this() {
        super(null);
    }

    override
    void decode(ByteBuffer buffer, Connection session) {
        if (!buffer.hasRemaining()) {
            return;
        }

        version(HUNT_DEBUG) {
            tracef("buffer: %s", buffer.toString());
            tracef("the server session %s received the %s bytes", session.getId(), buffer.remaining());
        }

        // Http2ServerConnection connection = cast(Http2ServerConnection) session.getAttachment();
        Http2ServerConnection connection = cast(Http2ServerConnection) session.getAttribute(HttpConnection.NAME);
        connection.getParser().parse(buffer);
    }

}
