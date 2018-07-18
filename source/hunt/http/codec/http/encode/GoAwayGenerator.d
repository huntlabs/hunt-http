module hunt.http.codec.http.encode.GoAwayGenerator;

import hunt.http.codec.http.frame.Flags;
import hunt.http.codec.http.frame.Frame;
import hunt.http.codec.http.frame.FrameType;
import hunt.http.codec.http.frame.GoAwayFrame;

import hunt.http.codec.http.encode.FrameGenerator;
import hunt.http.codec.http.encode.HeaderGenerator;

import hunt.container;
import hunt.util.exception;

import std.conv;


/**
*/
class GoAwayGenerator :FrameGenerator {
    this(HeaderGenerator headerGenerator) {
        super(headerGenerator);
    }

    override
    List!(ByteBuffer) generate(Frame frame) {
        GoAwayFrame goAwayFrame = cast(GoAwayFrame) frame;
        return Collections.singletonList(generateGoAway(goAwayFrame.getLastStreamId(), goAwayFrame.getError(), goAwayFrame.getPayload()));
    }

    ByteBuffer generateGoAway(int lastStreamId, int error, byte[] payload) {
        if (lastStreamId < 0)
            throw new IllegalArgumentException("Invalid last stream id: " ~ lastStreamId.to!string());

        // The last streamId + the error code.
        int fixedLength = 4 + 4;

        // Make sure we don't exceed the default frame max length.
        int maxPayloadLength = Frame.DEFAULT_MAX_LENGTH - fixedLength;
        if (payload != null && payload.length > maxPayloadLength)
            payload = payload[0 .. maxPayloadLength];

        int length = fixedLength + (payload != null ? cast(int)payload.length : 0);
        ByteBuffer header = generateHeader(FrameType.GO_AWAY, length, Flags.NONE, 0);

        header.put!int(lastStreamId);
        header.put!int(error);

        if (payload != null) {
            header.put(payload);
        }

        BufferUtils.flipToFlush(header, 0);
        return header;
    }
}
