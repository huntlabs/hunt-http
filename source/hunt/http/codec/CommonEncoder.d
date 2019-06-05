module hunt.http.codec.CommonEncoder;

import hunt.net.OutputEntry;
import hunt.net.AbstractConnection;
import hunt.net.EncoderChain;
import hunt.net.Session;

import hunt.Exceptions;
import hunt.util.Common;

import hunt.collection.ByteBuffer;
import hunt.logging;

/**
 * 
 */
class CommonEncoder : EncoderChain 
{
    void encode(Object message, Session session) {
        Object attachment = session.getAttachment();
        auto messageTypeInfo = typeid(message);

        version(HUNT_HTTP_DEBUG_MORE) {
            tracef("encoding... message: %s", messageTypeInfo.name);
            tracef("Session attachment: %s", typeid(attachment).name);
        }
        AbstractConnection connection = cast(AbstractConnection) attachment;
        assert(connection !is null, "Bad object");

        if (connection.isEncrypted()) {

            ByteBuffer messageBuffer = cast(ByteBuffer) message;
            if(messageBuffer !is null) {
                connection.encrypt(messageBuffer);
            // } else if (message instanceof ByteBuffer[]) {
            //     connection.encrypt(cast(ByteBuffer[]) message);
            } else {

                ByteBufferOutputEntry entry = cast(ByteBufferOutputEntry) message;
                if (entry !is null)  {
                    connection.encrypt(cast(ByteBufferOutputEntry) message);
                // } else if (message instanceof ByteBufferArrayOutputEntry) {
                //     connection.encrypt(cast(ByteBufferArrayOutputEntry) message);
                } else {
                    throw new IllegalArgumentException("the encoder object type error: " ~ messageTypeInfo.toString());
                }
            }
        } else {
            // if (messageTypeInfo == typeid(ByteBuffer)) 
            ByteBuffer messageBuffer = cast(ByteBuffer) message;
            if(messageBuffer !is null) {
                session.write(messageBuffer, Callback.NOOP);
            // } else if (messageTypeInfo == typeid(ByteBuffer[])) {
            //     session.write(cast(ByteBuffer[]) message, Callback.NOOP);
            } else { 
                ByteBufferOutputEntry entry = cast(ByteBufferOutputEntry) message;
                if (entry !is null) 
                    session.write(entry.getData(), entry.getCallback());
            // } else if (message instanceof ByteBufferArrayOutputEntry) {
            //     session.write(cast(ByteBufferArrayOutputEntry) message);
                else {
                    throw new IllegalArgumentException("the encoder object type error: " ~ messageTypeInfo.toString());
                }
            } 
        }
    }
}
