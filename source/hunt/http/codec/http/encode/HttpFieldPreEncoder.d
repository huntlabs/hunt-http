module hunt.http.codec.http.encode.HttpFieldPreEncoder;

import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.model.HttpVersion;
import hunt.http.codec.http.hpack.HpackEncoder;

/**
 * Interface to pre-encode HttpFields. Used by {@link PreEncodedHttpField}
 */
interface HttpFieldPreEncoder {

	/**
	 * The major version this encoder is for. Both HTTP/1.0 and HTTP/1.1 use the
	 * same field encoding, so the {@link HttpVersion#HTTP_1_0} should be return
	 * for all HTTP/1.x encodings.
	 * 
	 * @return The major version this encoder is for.
	 */
	HttpVersion getHttpVersion();

	byte[] getEncodedField(HttpHeader header, string headerString, string value);
}