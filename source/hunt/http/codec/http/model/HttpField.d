module hunt.http.codec.http.model.HttpField;

import hunt.http.codec.http.model.HttpHeaderValue;
import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.model.QuotedCSV;

import hunt.collection;
import hunt.text.Common;
import hunt.Exceptions;

import std.array;
import std.ascii;
import std.conv;
import std.uni;
import std.csv;
import std.string;

import hunt.logging;

class HttpField {
	private enum string __zeroquality = "q=0";
	private HttpHeader _header;
	private string _name;
	private string _value;
	// cached hashcode for case insensitive name
	private int hash = 0;

	this(HttpHeader header, string name, string value) {
		_header = header;
		_name = name; 
		_value = value;
	}

	this(HttpHeader header, string value) {
		this(header, header.asString(), value);
	}

	this(HttpHeader header, HttpHeaderValue value) {
		this(header, header.asString(), value.asString());
	}

	this(string name, string value) {
        // version(HUNT_DEBUG)
		// 	tracef("Field: name=%s, value=%s", name, value);
		HttpHeader h = HttpHeader.get(name);
		this(h, name, value);
	}

	HttpHeader getHeader() {
		return _header;
	}

	string getName() {
		return _name;
	}

	string getValue() {
		return _value;
	}

	int getIntValue() {
		return std.conv.to!int(_value);
	}

	long getLongValue() {
		try
		{
			return std.conv.to!long(_value);
		}
		catch(Exception ex)
		{
			throw new NumberFormatException(_value);
		}
	}

	string[] getValues() {
		if (_value.empty)
			return null;

		QuotedCSV list = new QuotedCSV(false, _value);
		return list.getValues(); //.toArray(new string[list.size()]);
		// return csvReader!(string)(_value).front().array;
	}

	/**
	 * Look for a value in a possible multi valued field
	 * 
	 * @param search
	 *            Values to search for (case insensitive)
	 * @return True iff the value is contained in the field value entirely or as
	 *         an element of a quoted comma separated list. List element
	 *         parameters (eg qualities) are ignored, except if they are q=0, in
	 *         which case the item itself is ignored.
	 */
	bool contains(string search) {
		if (search == null)
			return _value == null;
		if (search.length == 0)
			return false;
		if (_value == null)
			return false;
		if (search == (_value))
			return true;

		search = std.uni.toLower(search);

		int state = 0;
		int match = 0;
		int param = 0;

		for (int i = 0; i < _value.length; i++) {
			char c = _value[i];
			switch (state) {
			case 0: // initial white space
				switch (c) {
				case '"': // open quote
					match = 0;
					state = 2;
					break;

				case ',': // ignore leading empty field
					break;

				case ';': // ignore leading empty field parameter
					param = -1;
					match = -1;
					state = 5;
					break;

				case ' ': // more white space
				case '\t':
					break;

				default: // character
					match = std.ascii.toLower(c) == search[0] ? 1 : -1;
					state = 1;
					break;
				}
				break;

			case 1: // In token
				switch (c) {
				case ',': // next field
					// Have we matched the token?
					if (match == search.length)
						return true;
					state = 0;
					break;

				case ';':
					param = match >= 0 ? 0 : -1;
					state = 5; // parameter
					break;

				default:
					if (match > 0) {
						if (match < search.length)
							match = std.ascii.toLower(c) == search[match] ? (match + 1) : -1;
						else if (c != ' ' && c != '\t')
							match = -1;
					}
					break;

				}
				break;

			case 2: // In Quoted token
				switch (c) {
				case '\\': // quoted character
					state = 3;
					break;

				case '"': // end quote
					state = 4;
					break;

				default:
					if (match >= 0) {
						if (match < search.length)
							match = std.ascii.toLower(c) == search[match] ? (match + 1) : -1;
						else
							match = -1;
					}
				}
				break;

			case 3: // In Quoted character in quoted token
				if (match >= 0) {
					if (match < search.length)
						match = std.ascii.toLower(c) == search[match] ? (match + 1) : -1;
					else
						match = -1;
				}
				state = 2;
				break;

			case 4: // WS after end quote
				switch (c) {
				case ' ': // white space
				case '\t': // white space
					break;

				case ';':
					state = 5; // parameter
					break;

				case ',': // end token
					// Have we matched the token?
					if (match == search.length)
						return true;
					state = 0;
					break;

				default:
					// This is an illegal token, just ignore
					match = -1;
				}
				break;

			case 5: // parameter
				switch (c) {
				case ',': // end token
					// Have we matched the token and not q=0?
					if (param != __zeroquality.length && match == search.length)
						return true;
					param = 0;
					state = 0;
					break;

				case ' ': // white space
				case '\t': // white space
					break;

				default:
					if (param >= 0) {
						if (param < __zeroquality.length)
							param = std.ascii.toLower(c) == __zeroquality[param] ? (param + 1) : -1;
						else if (c != '0' && c != '.')
							param = -1;
					}

				}
				break;

			default:
				throw new IllegalStateException("");
			}
		}

		return param != __zeroquality.length && match == search.length;
	}

	override
	string toString() {
		string v = getValue();
		return getName() ~ ": " ~ (v.empty ? "" : v);
	}

	bool isSameName(HttpField field) {
		if (field is null)
			return false;
		if (field is this)
			return true;
		if (_header != HttpHeader.Null && _header == field.getHeader())
			return true;
		if (_name.equalsIgnoreCase(field.getName()))
			return true;
		return false;
	}

	private int nameHashCode() nothrow {
		int h = this.hash;
		int len = cast(int)_name.length;
		if (h == 0 && len > 0) {
			for (int i = 0; i < len; i++) {
				// simple case insensitive hash
				char c = _name[i];
				// assuming us-ascii (per last paragraph on
				// http://tools.ietf.org/html/rfc7230#section-3.2.4)
				if ((c >= 'a' && c <= 'z'))
					c -= 0x20;
				h = 31 * h + c;
			}
			this.hash = h;
		}
		return h;
	}

	override
	size_t toHash() @trusted nothrow {
		size_t vhc = hashOf(_value);
		if (_header ==  HttpHeader.Null)
			return vhc ^ nameHashCode();
		return vhc ^ hashOf(_header);
	}

	override bool opEquals(Object o)
	{
		if(o is this) return true;
    	if(o is null) return false;
		
		HttpField field = cast(HttpField) o;
		if(field is null)	return false;

		// trace("xx=>", _header.toString());
		// trace("2222=>", field.getHeader().toString());

		if (_header != field.getHeader())
			return false;

		if (std.string.icmp(_name, field.getName()) != 0)
			return false;

		string v = field.getValue();
		if (_value.empty && !v.empty)
			return false;
		return _value == v;
	}

	static class IntValueHttpField :HttpField {
		private int _int;

		this(HttpHeader header, string name, string value, int intValue) {
			super(header, name, value);
			_int = intValue;
		}

		this(HttpHeader header, string name, string value) {
			tracef("name=%s, value=%s",name, value);
			this(header, name, value, std.conv.to!int(value));
		}

		this(HttpHeader header, string name, int intValue) {
			this(header, name, std.conv.to!(string)(intValue), intValue);
		}

		this(HttpHeader header, int value) {
			this(header, header.asString(), value);
		}

		override
		int getIntValue() {
			return _int;
		}

		override
		long getLongValue() {
			return _int;
		}
	}

	static class LongValueHttpField :HttpField {
		private long _long;

		this(HttpHeader header, string name, string value, long longValue) {
			super(header, name, value);
			_long = longValue;
		}

		this(HttpHeader header, string name, string value) {
			this(header, name, value, std.conv.to!long(value));
		}

		this(HttpHeader header, string name, long value) {
			this(header, name, std.conv.to!string(value), value);
		}

		this(HttpHeader header, long value) {
			this(header, header.asString(), value);
		}

		override
		int getIntValue() {
			return cast(int) _long;
		}

		override
		long getLongValue() {
			return _long;
		}
	}

	static bool isCaseInsensitive() {
        return true;
    }
}
