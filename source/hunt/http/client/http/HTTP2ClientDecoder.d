module hunt.http.client.http.HTTP2ClientDecoder;

import hunt.http.client.http.HTTP2ClientConnection;

import hunt.net.DecoderChain;
import hunt.net.Session;
import hunt.logger;

import hunt.container.ByteBuffer;
import hunt.container.BufferUtils;


class HTTP2ClientDecoder : DecoderChain {

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

        HTTP2ClientConnection http2ClientConnection = cast(HTTP2ClientConnection) session.getAttachment();
        http2ClientConnection.getParser().parse(buffer);
    }

}
