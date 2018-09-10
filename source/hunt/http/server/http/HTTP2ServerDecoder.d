module hunt.http.server.http.HTTP2ServerDecoder;

import hunt.http.server.http.HTTP2ServerConnection;

import hunt.net.DecoderChain;
import hunt.net.Session;
import hunt.logging;


import hunt.container.ByteBuffer;

class HTTP2ServerDecoder : DecoderChain {    

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

        HTTP2ServerConnection connection = cast(HTTP2ServerConnection) session.getAttachment();
        connection.getParser().parse(buffer);
    }

}
