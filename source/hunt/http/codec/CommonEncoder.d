module hunt.http.codec.CommonEncoder;

import hunt.http.AbstractHttpConnection;

import hunt.collection.ByteBuffer;
import hunt.Exceptions;
import hunt.logging;
import hunt.net.codec.Encoder;
import hunt.net.Connection;
import hunt.net.secure.SecureSession;
import hunt.util.Common;


/**
 * 
 */
class CommonEncoder : EncoderChain {

    override void encode(Object message, Connection session) {

        ConnectionState connState = session.getState();
        version(HUNT_HTTP_DEBUG) {
            infof("ConnectionState: %s", connState);        
        }

        auto messageTypeInfo = typeid(message);
        version(HUNT_HTTP_DEBUG_MORE) {
            tracef("encoding... message: %s", messageTypeInfo.name);
        }

        if(connState == ConnectionState.Secured) {
            SecureSession secureSession = cast(SecureSession) session.getAttribute(SecureSession.NAME);
            ByteBuffer messageBuffer = cast(ByteBuffer) message;
            if(messageBuffer !is null) {
                // connection.encrypt(messageBuffer);
                secureSession.write(messageBuffer, Callback.NOOP);
            } else {

                throw new IllegalArgumentException("the encoder object type error: " ~ messageTypeInfo.toString());
                // ByteBufferOutputEntry entry = cast(ByteBufferOutputEntry) message;
                // if (entry !is null)  {
                //     implementationMissing(false);
                //     // connection.encrypt(cast(ByteBufferOutputEntry) message);
                // // } else if (message instanceof ByteBufferArrayOutputEntry) {
                // //     connection.encrypt(cast(ByteBufferArrayOutputEntry) message);
                // } else {
                //     throw new IllegalArgumentException("the encoder object type error: " ~ messageTypeInfo.toString());
                // }
            }
        } else {

            ByteBuffer messageBuffer = cast(ByteBuffer) message;
            if(messageBuffer !is null) {
                session.write(messageBuffer); // , Callback.NOOP
            } else { 
            //     ByteBufferOutputEntry entry = cast(ByteBufferOutputEntry) message;
            //     if (entry !is null) {
            //         session.write(entry.getData()); // , entry.getCallback()
            // // } else if (message instanceof ByteBufferArrayOutputEntry) {
            // //     session.write(cast(ByteBufferArrayOutputEntry) message);
            //    } else {
            //         throw new IllegalArgumentException("the encoder object type error: " ~ messageTypeInfo.toString());
            //     }
                throw new IllegalArgumentException("the encoder object type error: " ~ messageTypeInfo.toString());
            } 
        }
    }
}
