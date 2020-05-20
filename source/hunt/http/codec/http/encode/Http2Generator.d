module hunt.http.codec.http.encode.Http2Generator;

import hunt.http.codec.http.frame.DataFrame;
import hunt.http.codec.http.frame.Frame;
import hunt.http.codec.http.frame.FrameType;
import hunt.http.codec.http.hpack.HpackEncoder;

import hunt.http.codec.http.encode.DataGenerator;
import hunt.http.codec.http.encode.DisconnectGenerator;
import hunt.http.codec.http.encode.FrameGenerator;
import hunt.http.codec.http.encode.HeaderGenerator;
import hunt.http.codec.http.encode.HeadersGenerator;
import hunt.http.codec.http.encode.GoAwayGenerator;
import hunt.http.codec.http.encode.PingGenerator;
import hunt.http.codec.http.encode.PriorityGenerator;
import hunt.http.codec.http.encode.PrefaceGenerator;
import hunt.http.codec.http.encode.PushPromiseGenerator;
import hunt.http.codec.http.encode.ResetGenerator;
import hunt.http.codec.http.encode.SettingsGenerator;
import hunt.http.codec.http.encode.WindowUpdateGenerator;

import hunt.io.ByteBuffer;
import hunt.collection.List;
import hunt.logging;

import std.typecons;

/**
*/
class Http2Generator {
	private HeaderGenerator headerGenerator;
	private HpackEncoder hpackEncoder;
	private FrameGenerator[FrameType] generators;
	private DataGenerator dataGenerator;

	this() {
		this(4096, 0);
	}

	this(int maxDynamicTableSize, int maxHeaderBlockFragment) {

        version (HUNT_DEBUG) trace("Initializing Http2Generator");

		headerGenerator = new HeaderGenerator();
		hpackEncoder = new HpackEncoder(maxDynamicTableSize);

		// this.generators = new FrameGenerator[FrameType.values().length];
		this.generators[FrameType.HEADERS] = new HeadersGenerator(headerGenerator, hpackEncoder, maxHeaderBlockFragment);
		this.generators[FrameType.PRIORITY] = new PriorityGenerator(headerGenerator);
		this.generators[FrameType.RST_STREAM] = new ResetGenerator(headerGenerator);
		this.generators[FrameType.SETTINGS] = new SettingsGenerator(headerGenerator);
		this.generators[FrameType.PUSH_PROMISE] = new PushPromiseGenerator(headerGenerator, hpackEncoder);
		this.generators[FrameType.PING] = new PingGenerator(headerGenerator);
		this.generators[FrameType.GO_AWAY] = new GoAwayGenerator(headerGenerator);
		this.generators[FrameType.WINDOW_UPDATE] = new WindowUpdateGenerator(headerGenerator);
		this.generators[FrameType.CONTINUATION] = null; // Never generated explicitly.
		this.generators[FrameType.PREFACE] = new PrefaceGenerator();
		this.generators[FrameType.DISCONNECT] = new DisconnectGenerator();

		this.dataGenerator = new DataGenerator(headerGenerator);
	}

	void setHeaderTableSize(int headerTableSize) {
		hpackEncoder.setRemoteMaxDynamicTableSize(headerTableSize);
	}

	void setMaxFrameSize(int maxFrameSize) {
		headerGenerator.setMaxFrameSize(maxFrameSize);
	}

	// 
	T getControlGenerator(T)(FrameType type) if(is(T : FrameGenerator)) {
		return cast(T) this.generators[type];
	}
	
	List!(ByteBuffer) control(Frame frame) {
		return generators[frame.getType()].generate(frame);
	}

	/**
	 * Encode data frame to binary codes
	 * @param frame DataFrame
	 * @param maxLength The max length of DataFrame
	 * @return A pair of encoding result. The first field is frame length which contains header frame and data frame.
	 * The second field is binary codes.
	 */
	Tuple!(int, List!(ByteBuffer)) data(DataFrame frame, int maxLength) {
		return dataGenerator.generate(frame, maxLength);
	}
	
	void setMaxHeaderListSize(int value) {
        hpackEncoder.setMaxHeaderListSize(value);
    }
}
