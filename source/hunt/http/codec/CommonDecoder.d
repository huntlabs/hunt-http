module hunt.http.codec.CommonDecoder;

import hunt.io.ByteBuffer;
import hunt.io.BufferUtils;
import hunt.io.channel;
import hunt.Exceptions;
import hunt.logging;

import hunt.http.HttpConnection;
import hunt.http.HttpConnection;
import hunt.http.HttpConnection;
import hunt.net.codec.Decoder;
import hunt.net.Connection;
import hunt.net.Exceptions;
import hunt.net.secure.SecureSession;
import hunt.util.DateTime;

/**
 * 
 */
class CommonDecoder : DecoderChain {

    this(DecoderChain next) {
        super(next);
    }

    override DataHandleStatus decode(ByteBuffer buf, Connection session) {
        DataHandleStatus resultStatus = DataHandleStatus.Done;

        version(HUNT_METRIC) {
            import core.time;
            MonoTime startTime = MonoTime.currTime;
            debug infof("start decoding ...");
        }

        version(WITH_HUNT_SECURITY) {
            try {
                resultStatus = decodeSecureSession(buf, session);
            } catch(SSLHandshakeException ex) {
                warning(ex.msg);
                session.write(ErrorResponseMessage);
                // session.close();
            } catch(Exception ex) {
                warning(ex.msg);
                version(HUNT_HTTP_DEBUG) warning(ex);
                version(HUNT_DEBUG) {
                    session.write(ex.msg);
                } else {
                    session.write(ex.msg);
                }
                session.close();
            }
        } else {
           resultStatus = decodePlaintextSession(buf, session);
        }

        version(HUNT_METRIC) {
            Duration timeElapsed = MonoTime.currTime - startTime;
            warningf("decoding done for session %d in: %d microseconds",
                session.getId, timeElapsed.total!(TimeUnit.Microsecond)());
        }

        return resultStatus;
    }

    private DataHandleStatus decodePlaintextSession(ByteBuffer buf, Connection session) {
        DataHandleStatus resultStatus = DataHandleStatus.Done;

        ConnectionState connState;
        do {
            connState = session.getState();
            version(HUNT_HTTP_DEBUG) {
                if(connState == ConnectionState.Opening)
                    warning("Waiting for a http session...");
            }
        } while(connState == ConnectionState.Opening);
        
        version(HUNT_HTTP_DEBUG) {
            infof("ConnectionState: %s", connState);
        }
            
        DecoderChain next = getNext();
        if (next !is null) {
            resultStatus = next.decode(buf, session);
        } else {
            warning("The next decoder is null.");
            BufferUtils.clear(buf);
        }

        return resultStatus;
    }

    private DataHandleStatus decodeSecureSession(ByteBuffer buf, Connection session) {
        ConnectionState connState = session.getState();
        DataHandleStatus resultStatus = DataHandleStatus.Done;
            
        version(HUNT_HTTP_DEBUG) {
            infof("ConnectionState: %s", connState);
        }

        if(connState == ConnectionState.Secured) {
            DecoderChain next = getNext();
            SecureSession secureSession = cast(SecureSession) session.getAttribute(SecureSession.NAME);     
            assert(secureSession !is null, "secureSession is null");

            // version(HUNT_HTTP_DEBUG) tracef("Raw buffer: %s", buf.toString());
            ByteBuffer plaintext = secureSession.read(buf); // httpConnection.decrypt(buf);

            if (plaintext !is null && plaintext.hasRemaining() && next !is null) {
                version(HUNT_HTTP_DEBUG) {
                    infof("decrypted buffer: %s", plaintext.toString());
                }
                version(HUNT_HTTP_DEBUG_MORE) {
                    // int r = plaintext.remaining();
                    // if(r < 64) {
                    //     tracef("%(%02X %)", plaintext.peekRemaining());
                    // }
                    string msg = cast(string)plaintext.peekRemaining();
                    trace(msg);
                    // tracef("%(%02X %)", plaintext.peekRemaining());
                }
       
                resultStatus = next.decode(plaintext, session);
            } else {
                version(HUNT_HTTP_DEBUG) warning("No data decrypted!");
            }
        } else if(connState == ConnectionState.Securing) {
            version(HUNT_DEBUG) {
                info("TLS handshaking...");
            }
            // TLS handshake
            enum int MaxTimes = 5;
            SecureSession secureSession = waitForSecureSession(MaxTimes, session);

            if(secureSession is null) {
                version(HUNT_DEBUG) warning("Running handshake in another thread.");
                import std.parallelism;
                // auto handshakeTask = task(&handleTlsHandshake, buf, session, secureSession, next);
                auto handshakeTask = task(() {
                    // 
                    // FIXME: Needing refactor or cleanup -@zxp at 8/8/2019, 4:29:49 PM
                    // Maybe the buf needs be copied.
                    SecureSession s = waitForSecureSession(0, session);
                    if(s is null) {
                        warning("No SecureSession created");
                    } else {
                        handleTlsHandshake(buf, session, s);
                    }
                });
                taskPool.put(handshakeTask);
            } else {
                handleTlsHandshake(buf, session, secureSession);
            }

        } else {
           resultStatus = decodePlaintextSession(buf, session);
        }

        return resultStatus;
    }

    private SecureSession waitForSecureSession(int maxTimes, Connection session) {
        SecureSession secureSession;

        int count = 0;
        if(maxTimes>0) {
            do {
                secureSession = cast(SecureSession) session.getAttribute(SecureSession.NAME);
                count++;
                version(HUNT_HTTP_DEBUG) {
                    if(secureSession is null)
                        tracef("Waiting for a secure session...%d", count);
                }
            } while(count < maxTimes && secureSession is null); 
        } else {
            // Waiting until the SecureSession is avaliable.
            do {
                version(HUNT_HTTP_DEBUG_MORE) {
                    if(secureSession is null)
                        trace("Waiting for a secure session...");
                }
                secureSession = cast(SecureSession) session.getAttribute(SecureSession.NAME);
            } while(secureSession is null && session.getState() != ConnectionState.Error); 
        }

        return secureSession;
    }

    private void handleTlsHandshake(ByteBuffer buf, Connection session, 
        SecureSession secureSession) {

        DecoderChain next = getNext();
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
    }
}


// TODO: Tasks pending completion -@zhangxueping at 2019-12-23T19:11:48+08:00
// 
enum ErrorResponseMessage = "HTTP/1.1 400 Bad Request\n" ~
"Server: nginx/1.17.6\n" ~
"Date: Mon, 23 Dec 2019 10:54:33 GMT\n" ~
"Content-Type: text/html\n" ~
"Connection: close\n" ~

"<html>\n" ~
"<head><title>400 No required SSL certificate was sent</title></head>\n" ~
"<body>\n" ~
"<center><h1>400 Bad Request</h1></center>\n" ~
"<hr><center>Hunt</center>\n" ~
"</body>\n" ~
"</html>\n";