module hunt.http.codec.http.encode.Http1FieldPreEncoder;

import hunt.http.HttpHeader;
import hunt.http.HttpVersion;
import hunt.http.codec.http.encode.HttpFieldPreEncoder;


class Http1FieldPreEncoder : HttpFieldPreEncoder {

	override
	HttpVersion getHttpVersion() {
		return HttpVersion.HTTP_1_0;
	}

	override
	byte[] getEncodedField(HttpHeader header, string headerString, string value) {
		if (header != HttpHeader.Null) {
			byte[] bytesColonSpace = header.getBytesColonSpace();
			// int cbl = bytesColonSpace.length;
			// int newLength = cbl + value.length() + 2;
			// byte[] bytes = Arrays.copyOf(header.getBytesColonSpace(), cbl + value.length() + 2);
			// System.arraycopy(value.getBytes(UTF_8), 0, bytes, cbl, value.length());
			// byte[] bytes = new byte[newLength];
			// bytes[0..cbl] = bytesColonSpace[0..cbl];
			// bytes[cbl .. cbl+value.length] = value[];
			
			// bytes[bytes.length - 2] = cast(byte) '\r';
			// bytes[bytes.length - 1] = cast(byte) '\n';

			byte[] bytes = bytesColonSpace ~ cast(byte[])(value ~ "\r\n").dup;
			return bytes;
		}

		byte[] n = cast(byte[])headerString;
		byte[] v = cast(byte[])value;
		byte[] bytes = new byte[n.length + 2 + v.length + 2]; // Arrays.copyOf(n, n.length + 2 + v.length + 2);
		bytes[0..n.length] = n[0..$];

		bytes[n.length] = cast(byte) ':';
		bytes[n.length] = cast(byte) ' ';
		bytes[bytes.length - 2] = cast(byte) '\r';
		bytes[bytes.length - 1] = cast(byte) '\n';
		return bytes;
	}
}
