module hunt.http.HttpVersion;

import hunt.collection.ByteBuffer;

// import java.nio.charset.StandardCharsets;

import hunt.util.ObjectUtils;
import hunt.Exceptions;

import std.ascii;
import std.string;

// import hunt.http.utils.collection.ArrayTrie;
// import hunt.http.utils.collection.Trie;

struct HttpVersion {
	enum HttpVersion Null = HttpVersion("null", 0);
	enum HttpVersion HTTP_0_9 = HttpVersion("HTTP/0.9", 9);
	enum HttpVersion HTTP_1_0 = HttpVersion("HTTP/1.0", 10);
	enum HttpVersion HTTP_1_1 = HttpVersion("HTTP/1.1", 11);
	enum HttpVersion HTTP_2 = HttpVersion("HTTP/2.0", 20);

	private __gshared HttpVersion[string] CACHE;

	shared static this() {
		foreach (HttpVersion ver; HttpVersion.values())
			CACHE[ver.toString()] = ver;
	}

	mixin GetConstantValues!(HttpVersion);

	/**
	 * Optimized lookup to find a HTTP Version and whitespace in a byte array.
	 * 
	 * @param bytes
	 *            Array containing ISO-8859-1 characters
	 * @param position
	 *            The first valid index
	 * @param limit
	 *            The first non valid index
	 * @return A HttpMethod if a match or null if no easy match.
	 */
	static HttpVersion lookAheadGet(byte[] bytes, int position, int limit) {
		int length = limit - position;
		if (length < 9)
			return HttpVersion.Null;

		if (bytes[position + 4] == '/' && bytes[position + 6] == '.'
				&& std.ascii.isWhite(cast(char) bytes[position + 8])
				&& ((bytes[position] == 'H' && bytes[position + 1] == 'T'
					&& bytes[position + 2] == 'T' && bytes[position + 3] == 'P') || (bytes[position] == 'h'
					&& bytes[position + 1] == 't' && bytes[position + 2] == 't'
					&& bytes[position + 3] == 'p'))) {
			switch (bytes[position + 5]) {
			case '1':
				switch (bytes[position + 7]) {
				case '0':
					return HTTP_1_0;
				case '1':
					return HTTP_1_1;
				default:
					break;
				}
				break;
			case '2':
				if (bytes[position + 7] == '0') {
					return HTTP_2;
				}
				break;

			default:
				break;
			}
		}

		return HttpVersion.Null;
	}

	/**
	 * Optimised lookup to find a HTTP Version and trailing white space in a
	 * byte array.
	 * 
	 * @param buffer
	 *            buffer containing ISO-8859-1 characters
	 * @return A HttpVersion if a match or null if no easy match.
	 */
	static HttpVersion lookAheadGet(ByteBuffer buffer) {
		if (buffer.hasArray())
			return lookAheadGet(buffer.array(), buffer.arrayOffset() + buffer.position(),
					buffer.arrayOffset() + buffer.limit());
		return HttpVersion.Null;
	}

	private string _string;
	private byte[] _bytes;
	// private ByteBuffer _buffer;
	private int _version;

	this(string s, int ver) {
		_string = s;
		_bytes = cast(byte[]) s.dup;
		// _buffer = BufferUtils.toBuffer(_bytes);
		_version = ver;
	}

	byte[] toBytes() {
		return _bytes;
	}

	// ByteBuffer toBuffer() {
	// 	return _buffer.asReadOnlyBuffer();
	// }

	int getVersion() {
		return _version;
	}

	bool isSame(string s) {
		return s.length != 0 && std.string.icmp(_string, s) == 0;
	}

	string asString() {
		return _string;
	}

	string toString() {
		return _string;
	}

	int opCmp(ref const HttpVersion h) const {
		if (_version > h._version)
			return 1;
		else if (_version == h._version)
			return 0;
		else
			return -1;
	}

	int opCmp(const HttpVersion h) const {
		if (_version > h._version)
			return 1;
		else if (_version == h._version)
			return 0;
		else
			return -1;
	}

	/**
	 * Case insensitive fromString() conversion
	 * 
	 * @param version
	 *            the string to convert to enum constant
	 * @return the enum constant or null if version unknown
	 */
	static HttpVersion fromString(string ver) {
		return CACHE.get(ver, HttpVersion.Null);
	}

	static HttpVersion fromVersion(int ver) {
		switch (ver) {
		case 9:
			return HttpVersion.HTTP_0_9;
		case 10:
			return HttpVersion.HTTP_1_0;
		case 11:
			return HttpVersion.HTTP_1_1;
		case 20:
			return HttpVersion.HTTP_2;
		default:
			throw new IllegalArgumentException("");
		}
	}
}
