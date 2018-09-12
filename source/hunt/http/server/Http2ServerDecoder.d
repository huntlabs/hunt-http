module hunt.http.server.Http2ServerDecoder;

import hunt.http.server.Http2ServerConnection;

import hunt.net.DecoderChain;
import hunt.net.Session;
import hunt.logging;


import hunt.container.ByteBuffer;

class Http2ServerDecoder : DecoderChain {    

    this() {
        super(null);
    }

    override
    void decode(ByteBuffer buffer, Session session) {
        if (!buffer.hasRemaining()) {
            return;
        }

        version(HuntDebugMode) {
            tracef("buffer: %s", buffer.toString());
            tracef("the server session %s received the %s bytes", session.getSessionId(), buffer.remaining());
        }

        Http2ServerConnection connection = cast(Http2ServerConnection) session.getAttachment();
        connection.getParser().parse(buffer);
    }

}
