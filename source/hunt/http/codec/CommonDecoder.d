module hunt.http.codec.CommonDecoder;

import hunt.collection.ByteBuffer;
import hunt.Exceptions;
import hunt.logging;

import hunt.http.AbstractHttpConnection;
import hunt.http.HttpConnection;
import hunt.http.HttpConnectionType;
import hunt.net.codec.Decoder;
import hunt.net.Connection;
import hunt.net.secure.SecureSession;

/**
 * 
 */
class CommonDecoder : DecoderChain {

    this(DecoderChain next) {
        super(next);
    }

    override void decode(ByteBuffer buf, Connection session) {
        version(HUNT_METRIC) {
            import core.time;
            MonoTime startTime = MonoTime.currTime;
            debug infof("start decoding ...");
        }

        version(WITH_HUNT_SECURITY) {
            decodeSecureSession(buf, session);
        } else {
            decodePlaintextSession(buf, session);
        }

        version(HUNT_METRIC) {
            Duration timeElapsed = MonoTime.currTime - startTime;
            warningf("decoding done for session %d in: %d microseconds",
                session.getId, timeElapsed.total!(TimeUnit.Microsecond)());
        }
    }

    private void decodePlaintextSession(ByteBuffer buf, Connection session) {

        ConnectionState connState;
        do {
            connState = session.getState();
            version(HUNT_HTTP_DEBUG) {
                if(connState == ConnectionState.Opening)
                    warning("Waiting for a http session...");
            }
        } while(connState == ConnectionState.Opening);
            
        DecoderChain next = getNext();
        version(HUNT_HTTP_DEBUG) {
            infof("ConnectionState: %s", connState);
        }

        if (next !is null) {
            next.decode(buf, session);
        } else {
            warning("The next decoder is null.");
        }
    }

    private void decodeSecureSession(ByteBuffer buf, Connection session) {
        ConnectionState connState = session.getState();
            
        DecoderChain next = getNext();
        version(HUNT_HTTP_DEBUG) {
            infof("ConnectionState: %s", connState);
        }

        if(connState == ConnectionState.Secured) {
            SecureSession secureSession = cast(SecureSession) session.getAttribute(SecureSession.NAME);     
            assert(secureSession !is null)  ;

            ByteBuffer plaintext = secureSession.read(buf); // httpConnection.decrypt(buf);
            if (plaintext !is null && plaintext.hasRemaining() && next !is null) {
                next.decode(plaintext, session);
            } else {
                warning("The next decoder is null.");
            }
        } else if(connState == ConnectionState.Securing) {

            version(HUNT_DEBUG) {
                warning("TLS handshaking...");
            }

            SecureSession secureSession;
            // Waiting until the secureSession becames avaliable.
            do {
                secureSession = cast(SecureSession) session.getAttribute(SecureSession.NAME);
                version(HUNT_HTTP_DEBUG_MORE) {
                    if(secureSession is null)
                        warning("Waiting for a secure session...");
                }
            } while(secureSession is null && session.getState() != ConnectionState.Error);

            // TLS handshake
            ByteBuffer plaintext = secureSession.read(buf);

            if (plaintext !is null && plaintext.hasRemaining()) {
                version(HUNT_DEBUG) {
                    tracef("The session %s handshake finished and received cleartext size %s",
                            session.getId(), plaintext.remaining());
                }

                AbstractHttpConnection httpConnection = cast(AbstractHttpConnection) session.getAttribute(HttpConnection.NAME);
                version(HUNT_HTTP_DEBUG) {
                    tracef("http connection: %s", httpConnection is null ? "null" : typeid(httpConnection).name);
                }

                if (httpConnection !is null) {
                    if (next !is null) 
                        next.decode(plaintext, session);
                    else 
                        warning("The next decoder is null.");
                } else {
                    warningf("httpConnection is null");
                    throw new IllegalStateException("the http connection has not been created");
                }
            } else {
                version(HUNT_DEBUG) {
                    if (secureSession.isHandshakeFinished()) {
                        tracef("The ssl session %s need more data", session.getId());
                    } else {
                        tracef("The ssl session %s is shaking hand", session.getId());
                    }
                }
            }
        } else {
            decodePlaintextSession(buf, session);
        }
    }
}
