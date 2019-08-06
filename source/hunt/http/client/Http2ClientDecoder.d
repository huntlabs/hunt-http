module hunt.http.client.Http2ClientDecoder;

import hunt.http.client.Http2ClientConnection;

import hunt.net.codec.Decoder;
import hunt.net.Connection;
import hunt.logging;

import hunt.collection.ByteBuffer;
import hunt.collection.BufferUtils;


class Http2ClientDecoder : DecoderChain {

    this() {
        super(null);
    }

    override
    void decode(ByteBuffer buffer, Connection session) {
        if (!buffer.hasRemaining())
            return;

        version(HUNT_DEBUG) {
            tracef("the client session %s received the %s bytes", session.getId(), buffer.remaining());
        }

        Http2ClientConnection http2ClientConnection = cast(Http2ClientConnection) session.getAttachment();
        http2ClientConnection.getParser().parse(buffer);
    }

}
