module hunt.http.codec.http.encode.WindowUpdateGenerator;

import hunt.http.codec.http.frame.Flags;
import hunt.http.codec.http.frame.Frame;
import hunt.http.codec.http.frame.FrameType;
import hunt.http.codec.http.frame.WindowUpdateFrame;

import hunt.http.codec.http.encode.FrameGenerator;
import hunt.http.codec.http.encode.HeaderGenerator;

import hunt.container;
import hunt.lang.exception;

import std.conv;

/**
*/
class WindowUpdateGenerator :FrameGenerator {
    this(HeaderGenerator headerGenerator) {
        super(headerGenerator);
    }

    override
    List!(ByteBuffer) generate(Frame frame) {
        WindowUpdateFrame windowUpdateFrame = cast(WindowUpdateFrame) frame;
        return Collections.singletonList(generateWindowUpdate(windowUpdateFrame.getStreamId(), windowUpdateFrame.getWindowDelta()));
    }

    ByteBuffer generateWindowUpdate(int streamId, int windowUpdate) {
        if (windowUpdate < 0)
            throw new IllegalArgumentException("Invalid window update: " ~ windowUpdate.to!string);

        ByteBuffer header = generateHeader(FrameType.WINDOW_UPDATE, 4, Flags.NONE, streamId);
        header.put!int(windowUpdate);
        BufferUtils.flipToFlush(header, 0);
        return header;
    }
}
