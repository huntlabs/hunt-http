module hunt.http.client.http.Http2ClientDecoder;

import hunt.http.client.http.Http2ClientConnection;

import hunt.net.DecoderChain;
import hunt.net.Session;
import hunt.logging;

import hunt.container.ByteBuffer;
import hunt.container.BufferUtils;


class Http2ClientDecoder : DecoderChain {

    this() {
        super(null);
    }

    override
    void decode(ByteBuffer buffer, Session session) {
        if (!buffer.hasRemaining())
            return;

        version(HuntDebugMode) {
            tracef("the client session %s received the %s bytes", session.getSessionId(), buffer.remaining());
        }

        Http2ClientConnection http2ClientConnection = cast(Http2ClientConnection) session.getAttachment();
        http2ClientConnection.getParser().parse(buffer);
    }

}
