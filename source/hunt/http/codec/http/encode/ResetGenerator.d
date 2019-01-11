module hunt.http.codec.http.encode.ResetGenerator;

import hunt.http.codec.http.frame.Flags;
import hunt.http.codec.http.frame.Frame;
import hunt.http.codec.http.frame.FrameType;
import hunt.http.codec.http.frame.ResetFrame;

import hunt.http.codec.http.encode.FrameGenerator;
import hunt.http.codec.http.encode.HeaderGenerator;

import hunt.collection;
import hunt.Exceptions;

import std.conv;


/**
*/
class ResetGenerator :FrameGenerator {
    this(HeaderGenerator headerGenerator) {
        super(headerGenerator);
    }

    override
    List!(ByteBuffer) generate(Frame frame) {
        ResetFrame resetFrame = cast(ResetFrame) frame;
        return Collections.singletonList(generateReset(resetFrame.getStreamId(), resetFrame.getError()));
    }

    ByteBuffer generateReset(int streamId, int error) {
        if (streamId < 0)
            throw new IllegalArgumentException("Invalid stream id: " ~ streamId.to!string);

        ByteBuffer header = generateHeader(FrameType.RST_STREAM, 4, Flags.NONE, streamId);
        header.put!int(error);
        BufferUtils.flipToFlush(header, 0);
        return header;
    }
}
