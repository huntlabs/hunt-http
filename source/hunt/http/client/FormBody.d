module hunt.http.client.FormBody;

import hunt.http.client.RequestBody;

import hunt.collection.ByteBuffer;
import hunt.collection.HeapByteBuffer;
import hunt.collection.BufferUtils;
import hunt.Exceptions;
import hunt.net.util.UrlEncoded;
import hunt.util.MimeType;

import std.array;
import std.conv;
import std.container;


/**
*/
final class FormBody : RequestBody {
	private enum CONTENT_TYPE = "application/x-www-form-urlencoded"; // MimeType.TEXT_PLAIN;

	private string[] _encodedNames;
	private string[] _encodedValues;
    private bool _isEncoded = false;

	this(string[] encodedNames, string[] encodedValues) {
		this._encodedNames = encodedNames;
		this._encodedValues = encodedValues;

        super();
	}

	/** The number of key-value pairs in this form-encoded body. */
	int size() {
		return cast(int) _encodedNames.length;
	}

	string encodedName(int index) {
		return _encodedNames[index];
	}

	string name(int index) {
		return UrlEncoded.decodeString(_encodedNames[index]);
	}

	string encodedValue(int index) {
		return _encodedValues[index];
	}

	string value(int index) {
		return UrlEncoded.decodeString(_encodedValues[index]);
	}

	override string contentType() {
		return CONTENT_TYPE;
	}

	override size_t contentLength() {
        if(!_isEncoded) {
            encode();
        }

		return _contentLength;
	}

	override ByteBuffer content() {
        if(!_isEncoded) { 
            encode();
        }
		return _content;
	}
	//   override void writeTo(BufferedSink sink) {
	//     writeOrCountBytes(sink, false);
	//   }

	/**
   * Either writes this request to {@code sink} or measures its content length. We have one method
   * do double-duty to make sure the counting and content are consistent, particularly when it comes
   * to awkward operations like measuring the encoded length of header strings, or the
   * length-in-digits of an encoded integer.
   */
	private void encode() {

		for (size_t i = 0; i < _encodedNames.length; i++) {
			if (i > 0)
				_content.put('&');
			_content.put(cast(byte[])_encodedNames[i]);
			_content.put('=');
			_content.put(cast(byte[])_encodedValues[i]);
		}

        _isEncoded = true;
		_contentLength = cast(size_t)_content.position();
		_content.flip();
	}

	static final class Builder {
		private Array!string names;
		private Array!string values;
		// private final Charset charset;

		this() {
			// this(null);
		}

		// this(Charset charset) {
		//   this.charset = charset;
		// }

		Builder add(string name, string value) {
			if (name.empty)
				throw new NullPointerException("name is empty");
			if (value.empty)
				throw new NullPointerException("value is empty");

			names.insertBack(UrlEncoded.encodeString(name));
			values.insertBack(UrlEncoded.encodeString(value));

			return this;
		}

		Builder add(T)(string name, T value) if(!is(T == string)) {
			return add(name, to!string(value));
		}

		Builder addEncoded(string name, string value) {
			if (name.empty)
				throw new NullPointerException("name is empty");
			if (value.empty)
				throw new NullPointerException("value is empty");

			names.insertBack(name);
			values.insertBack(value);
			return this;
		}

		FormBody build() {
			return new FormBody(names.array, values.array);
		}
	}
}

alias FormBodyBuilder = FormBody.Builder;
