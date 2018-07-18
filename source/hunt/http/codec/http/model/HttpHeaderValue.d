//
//  ========================================================================
//  Copyright (c) 1995-2015 Mort Bay Consulting Pty. Ltd.
//  ------------------------------------------------------------------------
//  All rights reserved. This program and the accompanying materials
//  are made available under the terms of the Eclipse Public License v1.0
//  and Apache License v2.0 which accompanies this distribution.
//
//      The Eclipse Public License is available at
//      http://www.eclipse.org/legal/epl-v10.html
//
//      The Apache License v2.0 is available at
//      http://www.opensource.org/licenses/apache2.0.php
//
//  You may elect to redistribute this code under either of these licenses.
//  ========================================================================
//

module hunt.http.codec.http.model.HttpHeaderValue;

import hunt.http.codec.http.model.HttpHeader;
import hunt.util.traits;

import std.algorithm;
import std.string;
// import hunt.container.ByteBuffer;
// import java.nio.charset.StandardCharsets;
// import java.util.EnumSet;

// import hunt.http.utils.collection.ArrayTrie;
// import hunt.http.utils.collection.Trie;

/**
 * 
 */
struct HttpHeaderValue {

	enum HttpHeaderValue CLOSE = HttpHeaderValue("close");
    enum HttpHeaderValue CHUNKED = HttpHeaderValue("chunked");
    enum HttpHeaderValue GZIP = HttpHeaderValue("gzip");
    enum HttpHeaderValue IDENTITY = HttpHeaderValue("identity");
    enum HttpHeaderValue KEEP_ALIVE = HttpHeaderValue("keep-alive");
    enum HttpHeaderValue CONTINUE = HttpHeaderValue("100-continue");
    enum HttpHeaderValue PROCESSING = HttpHeaderValue("102-processing");
    enum HttpHeaderValue TE = HttpHeaderValue("TE");
    enum HttpHeaderValue BYTES = HttpHeaderValue("bytes");
    enum HttpHeaderValue NO_CACHE = HttpHeaderValue("no-cache");
    enum HttpHeaderValue UPGRADE = HttpHeaderValue("Upgrade");
    enum HttpHeaderValue UNKNOWN = HttpHeaderValue("::UNKNOWN::");	


	private static HttpHeader[] __known = [
			HttpHeader.CONNECTION, 
			HttpHeader.TRANSFER_ENCODING,
			HttpHeader.CONTENT_ENCODING
			];
	
	__gshared HttpHeaderValue[string] CACHE; 

	shared static this() {
		foreach (ref HttpHeaderValue value ; HttpHeaderValue.values())
        {
            if (value != UNKNOWN)
                CACHE[value.toString()] = value;
		}
	}

	mixin GetConstantValues!(HttpHeaderValue);

	private string _string;
	// private ByteBuffer buffer;
	
	private this(string s) {
		_string = s;
		// buffer = ByteBuffer.wrap(s.getBytes(StandardCharsets.UTF_8));
	}

	// ByteBuffer toBuffer() {
	// 	return buffer.asReadOnlyBuffer();
	// }

    bool isSame(string s) {
        return s.length != 0 && std.string.icmp(_string, s) == 0;
    }

	string asString() {
		return _string;
	}

	string toString() {
		return _string;
	}

	static bool hasKnownValues(HttpHeader header) {
		if (header == HttpHeader.Null)
			return false;
		return __known.canFind(header);
	}
}
