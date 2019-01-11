module hunt.http.codec.http.encode.PriorityGenerator;

import hunt.http.codec.http.frame.Flags;
import hunt.http.codec.http.frame.Frame;
import hunt.http.codec.http.frame.FrameType;
import hunt.http.codec.http.frame.PriorityFrame;

import hunt.http.codec.http.encode.FrameGenerator;
import hunt.http.codec.http.encode.HeaderGenerator;

import hunt.collection;
import hunt.Exceptions;

import std.conv;


/**
*/
class PriorityGenerator :FrameGenerator {
    this(HeaderGenerator headerGenerator) {
        super(headerGenerator);
    }

    override
    List!(ByteBuffer) generate(Frame frame) {
        PriorityFrame priorityFrame = cast(PriorityFrame) frame;
        return Collections.singletonList(generatePriority(
                priorityFrame.getStreamId(),
                priorityFrame.getParentStreamId(),
                priorityFrame.getWeight(),
                priorityFrame.isExclusive()));
    }

    ByteBuffer generatePriority(int streamId, int parentStreamId, int weight, bool exclusive) {
        ByteBuffer header = generateHeader(FrameType.PRIORITY, PriorityFrame.PRIORITY_LENGTH, Flags.NONE, streamId);
        generatePriorityBody(header, streamId, parentStreamId, weight, exclusive);
        BufferUtils.flipToFlush(header, 0);
        return header;
    }

    void generatePriorityBody(ByteBuffer header, int streamId, int parentStreamId, int weight,
                                     bool exclusive) {
        if (streamId < 0)
            throw new IllegalArgumentException("Invalid stream id: " ~ streamId.to!string());
        if (parentStreamId < 0)
            throw new IllegalArgumentException("Invalid parent stream id: " ~ parentStreamId.to!string());
        if (parentStreamId == streamId)
            throw new IllegalArgumentException("Stream " ~ streamId.to!string() ~ " cannot depend on stream " ~ parentStreamId.to!string());
        if (weight < 1 || weight > 256)
            throw new IllegalArgumentException("Invalid weight: " ~ weight.to!string());

        if (exclusive)
            parentStreamId |= 0x80_00_00_00;
        header.put!int(parentStreamId);
        header.put(cast(byte) (weight - 1));
    }
}
