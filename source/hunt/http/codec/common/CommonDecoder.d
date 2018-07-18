module hunt.http.codec.common.CommonDecoder;

import hunt.net.DecoderChain;
// import hunt.net.SecureSession;
// import hunt.net.Session;
import kiss.logger;


import hunt.container.ByteBuffer;

/**
 * 
 */
class CommonDecoder :DecoderChain
{

    // 

    this(DecoderChain next) {
        super(next);
    }

    // override
    // void decode(ByteBuffer buf, Session session) throws Exception {
    //     Object attachment = session.getAttachment();
    //     if (attachment instanceof AbstractConnection) {
    //         AbstractConnection connection = (AbstractConnection) attachment;
    //         if (connection.isEncrypted()) {
    //             ByteBuffer plaintext = connection.decrypt(buf);
    //             if (plaintext != null && plaintext.hasRemaining() && next != null) {
    //                 next.decode(plaintext, session);
    //             }
    //         } else {
    //             if (next != null) {
    //                 next.decode(buf, session);
    //             }
    //         }
    //     } else if (attachment instanceof SecureSession) { // TLS handshake
    //         SecureSession secureSession = (SecureSession) session.getAttachment();
    //         ByteBuffer plaintext = secureSession.read(buf);

    //         if (plaintext != null && plaintext.hasRemaining()) {
    //             version(HuntDebugMode) {
    //                 tracef("The session %s handshake finished and received cleartext size %s",
    //                         session.getSessionId(), plaintext.remaining());
    //             }
    //             if (session.getAttachment() instanceof AbstractConnection) {
    //                 if (next != null) {
    //                     next.decode(plaintext, session);
    //                 }
    //             } else {
    //                 throw new IllegalStateException("the connection has not been created");
    //             }
    //         } else {
    //             version(HuntDebugMode) {
    //                 if (secureSession.isHandshakeFinished()) {
    //                     tracef("The ssl session %s need more data", session.getSessionId());
    //                 } else {
    //                     tracef("The ssl session %s is shaking hand", session.getSessionId());
    //                 }
    //             }
    //         }
    //     }
    // }
}
