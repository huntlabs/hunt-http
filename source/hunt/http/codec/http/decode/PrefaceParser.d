module hunt.http.codec.http.decode.PrefaceParser;


import hunt.http.codec.http.decode.Parser;
import hunt.http.codec.http.frame.ErrorCode;
import hunt.http.codec.http.frame.PrefaceFrame;

import hunt.container.BufferUtils;
import hunt.logging;

import hunt.util.exception;
import hunt.container.ByteBuffer;

/**
*/
class PrefaceParser {
	

	private Parser.Listener listener;
	private int cursor;

	this(Parser.Listener listener) {
		this.listener = listener;
	}

	/**
	 * <p>
	 * Advances this parser after the
	 * {@link PrefaceFrame#PREFACE_PREAMBLE_BYTES}.
	 * </p>
	 * <p>
	 * This allows the HTTP/1.1 parser to parse the preamble of the preface,
	 * which is a legal HTTP/1.1 request, and this parser will parse the
	 * remaining bytes, that are not parseable by a HTTP/1.1 parser.
	 * </p>
	 */
	package void directUpgrade() {
		if (cursor != 0)
			throw new IllegalStateException("");
		cursor = PrefaceFrame.PREFACE_PREAMBLE_BYTES.length;
	}

	bool parse(ByteBuffer buffer) {
		while (buffer.hasRemaining()) {
			int currByte = buffer.get();
			if (currByte != PrefaceFrame.PREFACE_BYTES[cursor]) { // SM
				BufferUtils.clear(buffer);
				notifyConnectionFailure(cast(int)ErrorCode.PROTOCOL_ERROR, "invalid_preface");
				return false;
			}
			++cursor;
			if (cursor == PrefaceFrame.PREFACE_BYTES.length) {
				cursor = 0;
				version(HuntDebugMode)
					tracef("Parsed preface bytes");
				return true;
			}
		}
		return false;
	}

	protected void notifyConnectionFailure(int error, string reason) {
		try {
			listener.onConnectionFailure(error, reason);
		} catch (Exception x) {
			errorf("Failure while notifying listener %s", x, listener);
		}
	}
}
