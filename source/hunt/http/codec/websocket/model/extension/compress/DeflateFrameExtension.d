module hunt.http.codec.websocket.model.extension.compress;


import hunt.http.codec.websocket.exception.BadPayloadException;
import hunt.http.codec.websocket.frame.Frame;

import java.util.zip.DataFormatException;

/**
 * Implementation of the
 * <a href="https://tools.ietf.org/id/draft-tyoshino-hybi-websocket-perframe-deflate.txt">deflate-frame</a>
 * extension seen out in the wild.
 */
class DeflateFrameExtension : CompressExtension {
    override
    string getName() {
        return "deflate-frame";
    }

    override
    int getRsvUseMode() {
        return RSV_USE_ALWAYS;
    }

    override
    int getTailDropMode() {
        return TAIL_DROP_ALWAYS;
    }

    override
    void incomingFrame(Frame frame) {
        // Incoming frames are always non concurrent because
        // they are read and parsed with a single thread, and
        // therefore there is no need for synchronization.

        if (frame.getType().isControl() || !frame.isRsv1() || !frame.hasPayload()) {
            nextIncomingFrame(frame);
            return;
        }

        try {
            ByteAccumulator accumulator = newByteAccumulator();
            decompress(accumulator, frame.getPayload());
            decompress(accumulator, TAIL_BYTES_BUF.slice());
            forwardIncoming(frame, accumulator);
        } catch (DataFormatException e) {
            throw new BadPayloadException(e);
        }
    }

}
