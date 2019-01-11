module hunt.http.codec.http.encode.SettingsGenerator;

import hunt.http.codec.http.frame.Flags;
import hunt.http.codec.http.frame.Frame;
import hunt.http.codec.http.frame.FrameType;
import hunt.http.codec.http.frame.SettingsFrame;

import hunt.http.codec.http.encode.FrameGenerator;
import hunt.http.codec.http.encode.HeaderGenerator;

import hunt.collection;
import hunt.Exceptions;

/**
*/
class SettingsGenerator :FrameGenerator {
    this(HeaderGenerator headerGenerator) {
        super(headerGenerator);
    }

    override
    List!(ByteBuffer) generate(Frame frame) {
        SettingsFrame settingsFrame = cast(SettingsFrame) frame;
        return Collections.singletonList(generateSettings(settingsFrame.getSettings(), settingsFrame.isReply()));
    }

    ByteBuffer generateSettings(Map!(int, int) settings, bool reply) {
        // Two bytes for the identifier, four bytes for the value.
        int entryLength = 2 + 4;
        int length = entryLength * settings.size();
        if (length > getMaxFrameSize())
            throw new IllegalArgumentException("Invalid settings, too big");

        ByteBuffer header = generateHeader(FrameType.SETTINGS, length, reply ? Flags.ACK : Flags.NONE, 0);

        // foreach (Map.Entry!(int, int) entry ; settings) {
        //     header.putShort(entry.getKey().shortValue());
        //     header.putInt(entry.getValue());
        // }
        foreach (int k, int v; settings) {
            header.put!short(cast(short)k);
            header.put!int(v);
        }

        BufferUtils.flipToFlush(header, 0);
        return header;
    }
}
