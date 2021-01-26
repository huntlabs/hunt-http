module hunt.http.client.Http2ClientDecoder;

import hunt.http.client.Http2ClientConnection;
import hunt.http.HttpConnection;

import hunt.net.codec.Decoder;
import hunt.net.Connection;
import hunt.logging;

import hunt.io.ByteBuffer;
import hunt.io.BufferUtils;
import hunt.io.channel;


class Http2ClientDecoder : DecoderChain {

    this() {
        super(null);
    }

    override
    DataHandleStatus decode(ByteBuffer buffer, Connection session) {
        if (!buffer.hasRemaining())
            return DataHandleStatus.Done;

        version(HUNT_HTTP_DEBUG) {
            tracef("the client session %s received the %s bytes", session.getId(), buffer.remaining());
        }

        Http2ClientConnection http2ClientConnection = cast(Http2ClientConnection) session.getAttribute(HttpConnection.NAME); // session.getAttachment();
        http2ClientConnection.getParser().parse(buffer);
        
        return DataHandleStatus.Done;
    }

}
