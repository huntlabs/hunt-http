module hunt.http.codec.CommonDecoder;

import hunt.collection.ByteBuffer;
import hunt.Exceptions;
import hunt.logging;

import hunt.net.AbstractConnection;
import hunt.net.ConnectionType;
import hunt.net.DecoderChain;
import hunt.net.Session;
import hunt.net.secure.SecureSession;

/**
 * 
 */
class CommonDecoder : DecoderChain {

    this(DecoderChain next) {
        super(next);
    }

    override void decode(ByteBuffer buf, Session session) {
        version(HUNT_METRIC) {
            import core.time;
            import hunt.util.DateTime;
            MonoTime startTime = MonoTime.currTime;
            debug infof("start decoding ...");
        }
        Object attachment = session.getAttachment();
        version(HUNT_HTTP_DEBUG) {
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
                version(HUNT_DEBUG) {
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
                version(HUNT_DEBUG) {
                    if (secureSession.isHandshakeFinished()) {
                        tracef("The ssl session %s need more data", session.getSessionId());
                    } else {
                        tracef("The ssl session %s is shaking hand", session.getSessionId());
                    }
                }
            }
        } else {
            version(HUNT_DEBUG) warning("No handler for decoding");
        }

        version(HUNT_METRIC) {
            Duration timeElapsed = MonoTime.currTime - startTime;
            warningf("decoding done for session %d in: %d microseconds",
                session.getSessionId, timeElapsed.total!(TimeUnit.Microsecond)());
        }
    }
}
