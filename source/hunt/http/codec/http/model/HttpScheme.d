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

module hunt.http.codec.http.model.HttpScheme;

// import hunt.collection.ByteBuffer;

// import hunt.http.utils.collection.ArrayTrie;
// import hunt.http.utils.collection.Trie;
// import hunt.collection.BufferUtils;
// import hunt.util.Traits;

struct HttpScheme {
	enum HTTP = "http";
	enum HTTPS = "https";
	enum WS = "ws";
	enum WSS = "wss";

	enum string[] CACHE = [HTTP, HTTPS, WS, WSS];

	// shared static this() {
	// 	// for (HttpScheme version : HttpScheme.values())
	// 	// 	CACHE.insert(version.asString(), version);
	// 	CACHE ~= HTTP;
	// 	CACHE ~= HTTPS;
	// 	CACHE ~= WS;
	// 	CACHE ~= WSS;
	// }

	// private string _string;
	// private ByteBuffer buffer;

	// this(string s) {
	// 	_string = s;
	// 	buffer = BufferUtils.toBuffer(s);
	// }

	// mixin GetEnumValues!(HttpScheme);

	// ByteBuffer asByteBuffer() {
	// 	return buffer.asReadOnlyBuffer();
	// }

	// bool isSame(string s) {
	// 	return s != null && std.string.icmp(_string, s) == 0;
	// }

	// string asString() { return _string; }

	// override
	// string toString() {
	// 	return _string;
	// }

}
