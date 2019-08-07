module hunt.http.codec.CommonEncoder;

import hunt.net.OutputEntry;
import hunt.http.AbstractHttpConnection;
import hunt.net.codec.Encoder;
import hunt.net.Connection;
import hunt.net.secure.SecureSession;

import hunt.Exceptions;
import hunt.util.Common;

import hunt.collection.ByteBuffer;
import hunt.logging;

/**
 * 
 */
class CommonEncoder : EncoderChain 
{
    override void encode(Object message, Connection session) {

        ConnectionState connState = session.getState();
        errorf("State: %s, isSecured: %s", 
            connState, session.isSecured() );        

        // Object attachment = session.getAttachment();
        auto messageTypeInfo = typeid(message);

        version(HUNT_HTTP_DEBUG_MORE) {
            tracef("encoding... message: %s", messageTypeInfo.name);
            tracef("Connection attachment: %s", typeid(httpConnection).name);
        }

        if(connState == ConnectionState.Secured) {
            SecureSession secureSession = cast(SecureSession) session.getAttribute("SSL_CONNECTION");
            ByteBuffer messageBuffer = cast(ByteBuffer) message;
            if(messageBuffer !is null) {
                // connection.encrypt(messageBuffer);
                secureSession.write(messageBuffer, Callback.NOOP);
            // } else if (message instanceof ByteBuffer[]) {
            //     connection.encrypt(cast(ByteBuffer[]) message);
            } else {

                ByteBufferOutputEntry entry = cast(ByteBufferOutputEntry) message;
                if (entry !is null)  {
                    implementationMissing(false);
                    // connection.encrypt(cast(ByteBufferOutputEntry) message);
                // } else if (message instanceof ByteBufferArrayOutputEntry) {
                //     connection.encrypt(cast(ByteBufferArrayOutputEntry) message);
                } else {
                    throw new IllegalArgumentException("the encoder object type error: " ~ messageTypeInfo.toString());
                }
            }
        } else {

            // AbstractHttpConnection httpConnection = cast(AbstractHttpConnection) session.getAttribute("HTTP_CONNECTION");

            // version(HUNT_HTTP_DEBUG) {
            //     if(httpConnection !is null) {
            //         tracef("http connection: %s", typeid(httpConnection).name);
            //     }
            // }   

            ByteBuffer messageBuffer = cast(ByteBuffer) message;
            if(messageBuffer !is null) {
                session.write(messageBuffer); // , Callback.NOOP
            // } else if (messageTypeInfo == typeid(ByteBuffer[])) {
            //     session.write(cast(ByteBuffer[]) message, Callback.NOOP);
            } else { 
                ByteBufferOutputEntry entry = cast(ByteBufferOutputEntry) message;
                if (entry !is null) 
                    session.write(entry.getData()); // , entry.getCallback()
            // } else if (message instanceof ByteBufferArrayOutputEntry) {
            //     session.write(cast(ByteBufferArrayOutputEntry) message);
                else {
                    throw new IllegalArgumentException("the encoder object type error: " ~ messageTypeInfo.toString());
                }
            } 
        }




    //     AbstractHttpConnection connection = cast(AbstractHttpConnection) attachment;
    //     assert(connection !is null, "Bad object");

    //     if (connection.isSecured()) {

    //         ByteBuffer messageBuffer = cast(ByteBuffer) message;
    //         if(messageBuffer !is null) {
    //             connection.encrypt(messageBuffer);
    //         // } else if (message instanceof ByteBuffer[]) {
    //         //     connection.encrypt(cast(ByteBuffer[]) message);
    //         } else {

    //             ByteBufferOutputEntry entry = cast(ByteBufferOutputEntry) message;
    //             if (entry !is null)  {
    //                 connection.encrypt(cast(ByteBufferOutputEntry) message);
    //             // } else if (message instanceof ByteBufferArrayOutputEntry) {
    //             //     connection.encrypt(cast(ByteBufferArrayOutputEntry) message);
    //             } else {
    //                 throw new IllegalArgumentException("the encoder object type error: " ~ messageTypeInfo.toString());
    //             }
    //         }
    //     } else {
    //         // if (messageTypeInfo == typeid(ByteBuffer)) 
    //         ByteBuffer messageBuffer = cast(ByteBuffer) message;
    //         if(messageBuffer !is null) {
    //             session.write(messageBuffer); // , Callback.NOOP
    //         // } else if (messageTypeInfo == typeid(ByteBuffer[])) {
    //         //     session.write(cast(ByteBuffer[]) message, Callback.NOOP);
    //         } else { 
    //             ByteBufferOutputEntry entry = cast(ByteBufferOutputEntry) message;
    //             if (entry !is null) 
    //                 session.write(entry.getData()); // , entry.getCallback()
    //         // } else if (message instanceof ByteBufferArrayOutputEntry) {
    //         //     session.write(cast(ByteBufferArrayOutputEntry) message);
    //             else {
    //                 throw new IllegalArgumentException("the encoder object type error: " ~ messageTypeInfo.toString());
    //             }
    //         } 
    //     }
    }
}
