module hunt.http.codec.http.frame.PrefaceFrame;

import hunt.http.codec.http.frame.Frame;
import hunt.http.codec.http.frame.FrameType;

class PrefaceFrame :Frame {
	/**
	 * The bytes of the HTTP/2 preface that form a legal HTTP/1.1 request, used
	 * in the direct upgrade.
	 */
	enum PREFACE_PREAMBLE_BYTES = ("PRI * HTTP/2.0\r\n" ~ "\r\n");

	/**
	 * The HTTP/2 preface bytes.
	 */
	enum PREFACE_BYTES = ("PRI * HTTP/2.0\r\n" ~ "\r\n" ~ "SM\r\n" ~ "\r\n");

	this() {
		super(FrameType.PREFACE);
	}
}
