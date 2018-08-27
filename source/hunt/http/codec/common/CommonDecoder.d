module hunt.http.codec.common.CommonDecoder;

import hunt.net.DecoderChain;
// import hunt.net.secure.SecureSession;

import hunt.net.AbstractConnection;
import hunt.net.ConnectionType;
import hunt.net.DecoderChain;
import hunt.net.Session;
import hunt.net.secure.SecureSession;

import hunt.util.exception;

import hunt.logger;
import hunt.container.ByteBuffer;

/**
 * 
 */
class CommonDecoder : DecoderChain
{

    this(DecoderChain next) {
        super(next);
    }

    override void decode(ByteBuffer buf, Session session) {
        Object attachment = session.getAttachment();
        version(HuntDebugMode) {
            tracef("decoding with %s", typeid(attachment).name);
        }

        AbstractConnection connection = cast(AbstractConnection) attachment;
        SecureSession secureSession = cast(SecureSession) attachment;

        if (connection !is null) {
            if (connection.isEncrypted()) {
                ByteBuffer plaintext = connection.decrypt(buf);
                if (plaintext !is null && plaintext.hasRemaining() && next !is null) {
                    next.decode(plaintext, session);
                } else warning("The next decoder is null.");
            } else {
                if (next !is null) {
                    next.decode(buf, session);
                } else warning("The next decoder is null.");
            }
        } else if (secureSession !is null) { // TLS handshake
            ByteBuffer plaintext = secureSession.read(buf);

            if (plaintext !is null && plaintext.hasRemaining()) {
                version(HuntDebugMode) {
                    tracef("The session %s handshake finished and received cleartext size %s",
                            session.getSessionId(), plaintext.remaining());
                }

                // The attachment has been reset.
                connection = cast(AbstractConnection) session.getAttachment();
                if (connection !is null) {
                    if (next !is null) 
                        next.decode(plaintext, session);
                    else 
                        warning("The next decoder is null.");
                } else {
                        warningf("connection is null");
                    throw new IllegalStateException("the connection has not been created: ", );
                }
            } else {
                version(HuntDebugMode) {
                    if (secureSession.isHandshakeFinished()) {
                        tracef("The ssl session %s need more data", session.getSessionId());
                    } else {
                        tracef("The ssl session %s is shaking hand", session.getSessionId());
                    }
                }
            }
        } else {
            version(HuntDebugMode) warning("No handler");
        }
    }
}
