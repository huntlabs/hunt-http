module hunt.http.codec.common.CommonEncoder;

// import hunt.net.ByteBufferArrayOutputEntry;
import hunt.net.AbstractConnection;
import hunt.net.EncoderChain;
import hunt.net.Session;

import hunt.util.exception;
import hunt.util.functional;


import hunt.container.ByteBuffer;
import kiss.logger;

/**
 * 
 */
class CommonEncoder : EncoderChain 
{
    void encode(Object message, Session session) {
        Object attachment = session.getAttachment();
        auto messageTypeInfo = typeid(message);

        version(HuntDebugMode) {
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
            // } else if (message instanceof ByteBufferOutputEntry) {
            //     connection.encrypt(cast(ByteBufferOutputEntry) message);
            // } else if (message instanceof ByteBufferArrayOutputEntry) {
            //     connection.encrypt(cast(ByteBufferArrayOutputEntry) message);
            } else {
                throw new IllegalArgumentException("the encoder object type error: " ~ messageTypeInfo.toString());
            }
        } else {
            // if (messageTypeInfo == typeid(ByteBuffer)) 
            ByteBuffer messageBuffer = cast(ByteBuffer) message;
            if(messageBuffer !is null)
            {
                session.write(messageBuffer, Callback.NOOP);
            // } else if (messageTypeInfo == typeid(ByteBuffer[])) {
            //     session.write(cast(ByteBuffer[]) message, Callback.NOOP);
            // } else if (message instanceof ByteBufferOutputEntry) {
            //     session.write(cast(ByteBufferOutputEntry) message);
            // } else if (message instanceof ByteBufferArrayOutputEntry) {
            //     session.write(cast(ByteBufferArrayOutputEntry) message);
            } else {
                throw new IllegalArgumentException("the encoder object type error: " ~ messageTypeInfo.toString());
            }
        }
    }
}
