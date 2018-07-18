module hunt.http.codec.http.hpack.AuthorityHttpField;

import hunt.http.codec.http.model.HostPortHttpField;
import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.hpack.HpackContext;

import std.format;

class AuthorityHttpField :HostPortHttpField {
	static string AUTHORITY = HpackContext.STATIC_TABLE[1][0];

	this(string authority) {
		super(HttpHeader.C_AUTHORITY, AUTHORITY, authority);
	}

	override
	string toString() {
		return format("%s(preparsed h=%s p=%d)", super.toString(), getHost(), getPort());
	}
}
