module test.codec.websocket.UnitGenerator;

import hunt.http.codec.websocket.encode;
import hunt.http.codec.websocket.frame.Frame;
import hunt.http.codec.websocket.frame.WebSocketFrame;
import hunt.http.codec.websocket.stream.WebSocketPolicy;

import hunt.container;
import hunt.logging;

/**
 * Convenience Generator.
 */
class UnitGenerator : Generator {

    static ByteBuffer generate(Frame frame) {
        return generate([frame]);
    }

    /**
     * Generate All Frames into a single ByteBuffer.
     * <p>
     * This is highly inefficient and is not used in production! (This exists to make testing of the Generator easier)
     *
     * @param frames the frames to generate from
     * @return the ByteBuffer representing all of the generated frames provided.
     */
    static ByteBuffer generate(T = Frame)(T[] frames) {
        Generator generator = new UnitGenerator();

        // Generate into single bytebuffer
        int buflen = 0;
        foreach (Frame f ; frames) {
            buflen += f.getPayloadLength() + Generator.MAX_HEADER_LENGTH;
        }
        ByteBuffer completeBuf = ByteBuffer.allocate(buflen);
        BufferUtils.clearToFill(completeBuf);

        // Generate frames
        foreach (Frame f ; frames) {
            generator.generateWholeFrame(f, completeBuf);
        }

        BufferUtils.flipToFlush(completeBuf, 0);
        version(HUNT_DEBUG) {
            tracef("generate(%s frames) - %s", frames.length, BufferUtils.toDetailString(completeBuf));
        }
        return completeBuf;
    }

    /**
     * Generate a single giant buffer of all provided frames Not appropriate for production code, but useful for testing.
     *
     * @param frames the list of frames to generate from
     * @return the bytebuffer representing all of the generated frames
     */
    static ByteBuffer generate(List!WebSocketFrame frames) {
        // Create non-symmetrical mask (helps show mask bytes order issues)
        byte[] MASK = [0x11, 0x22, 0x33, 0x44];

        // the generator
        Generator generator = new UnitGenerator();

        // Generate into single bytebuffer
        int buflen = 0;
        foreach (WebSocketFrame f ; frames) {
            buflen += f.getPayloadLength() + Generator.MAX_HEADER_LENGTH;
        }
        ByteBuffer completeBuf = ByteBuffer.allocate(buflen);
        BufferUtils.clearToFill(completeBuf);

        // Generate frames
        foreach (WebSocketFrame f ; frames) {
            f.setMask(MASK); // make sure we have the test mask set
            BufferUtils.put(generator.generateHeaderBytes(f), completeBuf);
            ByteBuffer window = f.getPayload();
            if (BufferUtils.hasContent(window)) {
                BufferUtils.put(window, completeBuf);
            }
        }

        BufferUtils.flipToFlush(completeBuf, 0);
        version(HUNT_DEBUG) {
            tracef("generate(%s frames) - %s", frames.size(), BufferUtils.toDetailString(completeBuf));
        }
        return completeBuf;
    }

    this() {
        super(WebSocketPolicy.newServerPolicy());
    }

}
