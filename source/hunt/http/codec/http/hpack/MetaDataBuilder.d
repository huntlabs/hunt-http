module hunt.http.codec.http.hpack.MetaDataBuilder;

import hunt.http.codec.http.hpack.AuthorityHttpField;
import hunt.http.codec.http.model.BadMessageException;
import hunt.http.codec.http.model.HostPortHttpField;
import hunt.http.codec.http.model.HttpField;
import hunt.http.codec.http.model.HttpFields;
import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.model.HttpScheme;
import hunt.http.codec.http.model.HttpStatus;
import hunt.http.codec.http.model.HttpVersion;
import hunt.http.codec.http.model.MetaData;
import hunt.http.codec.http.model.StaticTableHttpField;

import hunt.util.exception;

import std.algorithm;
import std.array;
import std.conv;

import kiss.logger;

/**
*/
class MetaDataBuilder {
	private int _maxSize;
	private int _size;
	private int _status;
	private string _method;
	private string _scheme;
	private HostPortHttpField _authority;
	private string _path;
	private long _contentLength = long.min;
	private HttpFields _fields;

	/**
	 * @param maxHeadersSize
	 *            The maximum size of the headers, expressed as total name and
	 *            value characters.
	 */
	this(int maxHeadersSize) {
		_maxSize = maxHeadersSize;
		_fields = new HttpFields(10);
	}

	/**
	 * Get the maxSize.
	 * 
	 * @return the maxSize
	 */
	int getMaxSize() {
		return _maxSize;
	}

	/**
	 * Get the size.
	 * 
	 * @return the current size in bytes
	 */
	int getSize() {
		return _size;
	}

	void emit(HttpField field) {
		HttpHeader header = field.getHeader();
		string name = field.getName();
		string value = field.getValue();
		int field_size = cast(int)(name.length + (value == null ? 0 : value.length));
		_size += field_size + 32;
		if (_size > _maxSize)
			throw new BadMessageException(HttpStatus.REQUEST_HEADER_FIELDS_TOO_LARGE_431,
					"Header size " ~ to!string(_size) ~ ">" ~ to!string(_maxSize));

		string fieldTypeName = typeof(field).stringof;
		// trace("fieldTypeName: ", fieldTypeName);
		if (fieldTypeName.startsWith("StaticTableHttpField")) {
			if(header == HttpHeader.C_STATUS){
				StaticTableHttpField!int staticField = cast(StaticTableHttpField!int) field;
				_status = staticField.getStaticValue();
			}
			else if(header == HttpHeader.C_METHOD){
				_method = value;
			}
			else if(header == HttpHeader.C_SCHEME){
				StaticTableHttpField!string staticField = cast(StaticTableHttpField!string) field;
				_scheme = staticField.getStaticValue();
			}
			else
				throw new IllegalArgumentException(name);

		} else if (header != HttpHeader.Null) {
			if(header == HttpHeader.C_STATUS)
				_status = field.getIntValue();
			else if(header == HttpHeader.C_METHOD)
				_method = value;
			else if(header == HttpHeader.C_SCHEME){
				if (value != null)
					_scheme = value; // HttpScheme.CACHE[value];
			}
			else if(header == HttpHeader.C_AUTHORITY) {
				if (typeid(field) == typeid(HostPortHttpField))
					_authority = cast(HostPortHttpField) field;
				else if (value != null)
					_authority = new AuthorityHttpField(value);
			}
			else if(header == HttpHeader.HOST){
				// :authority fields must come first. If we have one, ignore the
				// host header as far as authority goes.
				if (_authority is null) {
					if (typeid(field) == typeid(HostPortHttpField))
						_authority = cast(HostPortHttpField) field;
					else if (value != null)
						_authority = new AuthorityHttpField(value);
				}
				_fields.add(field);
			}
			else if(header == HttpHeader.C_PATH)
				_path = value;
			else if(header == HttpHeader.CONTENT_LENGTH) {
				_contentLength = field.getLongValue();
				_fields.add(field);
			}
			else
			{
				if (name[0] != ':')
					_fields.add(field);
			}
		} else {
			if (name[0] != ':')
				_fields.add(field);
		}
	}

	MetaData build() {
		try {
			HttpFields fields = _fields;
			_fields = new HttpFields(std.algorithm.max(10, fields.size() + 5));

			if (!_method.empty)
				return new MetaData.Request(_method, _scheme, _authority, _path, HttpVersion.HTTP_2, fields,
						_contentLength);
			if (_status != 0)
				return new MetaData.Response(HttpVersion.HTTP_2, _status, fields, _contentLength);
			return new MetaData(HttpVersion.HTTP_2, fields, _contentLength);
		} finally {
			_status = 0;
			_method = null;
			_scheme = null;
			_authority = null;
			_path = null;
			_size = 0;
			_contentLength = long.min;
		}
	}

	/**
	 * Check that the max size will not be exceeded.
	 * 
	 * @param length
	 *            the length
	 * @param huffman
	 *            the huffman name
	 */
	void checkSize(int length, bool huffman) {
		// Apply a huffman fudge factor
		if (huffman)
			length = (length * 4) / 3;
		if ((_size + length) > _maxSize)
			throw new BadMessageException(HttpStatus.REQUEST_HEADER_FIELDS_TOO_LARGE_431,
					"Header size " ~ to!string(_size + length) ~ ">" ~ to!string(_maxSize));
	}
}
