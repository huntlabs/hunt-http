module hunt.http.HttpFields;

import hunt.http.HttpField;
import hunt.http.HttpHeader;
import hunt.http.QuotedCSV;

import hunt.collection;
import hunt.Exceptions;
import hunt.logging.ConsoleLogger;
import hunt.text.Common;
import hunt.text.QuotedStringTokenizer;
import hunt.text.StringBuilder;
import hunt.text.StringTokenizer;
import hunt.text.StringUtils;
import hunt.util.Common;

import std.array;
import std.algorithm;
import std.container.array;
import std.conv;
import std.datetime;
import std.string;
import std.range;


/**
 * HTTP Fields. A collection of HTTP header and or Trailer fields.
 *
 * <p>
 * This class is not synchronized as it is expected that modifications will only
 * be performed by a single thread.
 * 
 * <p>
 * The cookie handling provided by this class is guided by the Servlet
 * specification and RFC6265.
 *
 */
class HttpFields : Iterable!HttpField {
	// static string __separators = ", \t";

	private HttpField[] _fields;
	private int _size;

	/**
	 * Initialize an empty HttpFields.
	 */
	this() {
		_fields = new HttpField[20];
	}

	/**
	 * Initialize an empty HttpFields.
	 * 
	 * @param capacity
	 *            the capacity of the http fields
	 */
	this(int capacity) {
		_fields = new HttpField[capacity];
	}

	/**
	 * Initialize HttpFields from copy.
	 * 
	 * @param fields
	 *            the fields to copy data from
	 */
	this(HttpFields fields) {
		_fields = fields._fields.dup ~ new HttpField[10];
		_size = fields.size();
	}

	int size() {
		return _size;
	}

	InputRange!HttpField iterator() {
		return inputRangeObject(_fields[0 .. _size]);
	}

	int opApply(scope int delegate(ref HttpField) dg) {
		int result = 0;
		foreach (HttpField v; _fields[0 .. _size]) {
			result = dg(v);
			if (result != 0)
				return result;
		}
		return result;
	}

	int opApply(scope int delegate(string name, string value) dg) {
		int result = 0;
		foreach (HttpField v; _fields[0 .. _size]) {
			result = dg(v.getName(), v.getValue());
			if (result != 0)
				return result;
		}
		return result;
	}

	/**
	 * Get Collection of header names.
	 * 
	 * @return the unique set of field names.
	 */
	Set!string getFieldNamesCollection() {
		Set!string set = new HashSet!string(_size);
		foreach (HttpField f; _fields[0 .. _size]) {
			if (f !is null)
				set.add(f.getName());
		}
		return set;
	}

	/**
	 * Get enumeration of header _names. Returns an enumeration of strings
	 * representing the header _names for this request.
	 * 
	 * @return an enumeration of field names
	 */
	InputRange!string getFieldNames() {
		bool[string] set;
		foreach (HttpField f; _fields[0 .. _size]) {
			if (f !is null)
				set[f.getName()] = true;
		}
		return inputRangeObject(set.keys);
	}

	// InputRange!string getFieldNames() {
	// 	// return Collections.enumeration(getFieldNamesCollection());
	// 	// return getFieldNamesCollection().toArray();
	// 	Array!string set;
	// 	foreach (HttpField f ; _fields[0.._size]) {
	// 		if (f !is null)
	// 			set.insertBack(f.getName());
	// 	}
	// 	// Enumeration!string r = new RangeEnumeration!string(inputRangeObject(set[].array));
	// 	return inputRangeObject(set[].array);
	// }

	HttpField[] allFields() {
		return _fields[0 .. _size];
	}

	/**
	 * Get a Field by index.
	 * 
	 * @param index
	 *            the field index
	 * @return A Field value or null if the Field value has not been set
	 */
	HttpField getField(int index) {
		if (index >= _size)
			throw new NoSuchElementException("");
		return _fields[index];
	}

	HttpField getField(HttpHeader header) {
		for (int i = 0; i < _size; i++) {
			HttpField f = _fields[i];
			if (f.getHeader() == header)
				return f;
		}
		return null;
	}

	HttpField getField(string name) {
		for (int i = 0; i < _size; i++) {
			HttpField f = _fields[i];
			if (f.getName().equalsIgnoreCase(name))
				return f;
		}
		return null;
	}

	bool contains(HttpField field) {
		for (int i = _size; i-- > 0;) {
			HttpField f = _fields[i];
			if (f.isSameName(field) && (f.opEquals(field) || f.contains(field.getValue())))
				return true;
		}
		return false;
	}

	bool contains(HttpHeader header, string value) {
		for (int i = _size; i-- > 0;) {
			HttpField f = _fields[i];
			if (f.getHeader() == header && f.contains(value))
				return true;
		}
		return false;
	}

	bool contains(string name, string value) {
		for (int i = _size; i-- > 0;) {
			HttpField f = _fields[i];
			if (f.getName().equalsIgnoreCase(name) && f.contains(value))
				return true;
		}
		return false;
	}

	bool contains(HttpHeader header) {
		for (int i = _size; i-- > 0;) {
			HttpField f = _fields[i];
			if (f.getHeader() == header)
				return true;
		}
		return false;
	}

	bool containsKey(string name) {
		for (int i = _size; i-- > 0;) {
			HttpField f = _fields[i];
			if (std.string.icmp(f.getName(), name) == 0)
				return true;
		}
		return false;
	}

	string get(HttpHeader header) {
		for (int i = 0; i < _size; i++) {
			HttpField f = _fields[i];
			if (f.getHeader() == header)
				return f.getValue();
		}
		return null;
	}

	string get(string header) {
		for (int i = 0; i < _size; i++) {
			HttpField f = _fields[i];
			if (f.getName().equalsIgnoreCase(header))
				return f.getValue();
		}
		return null;
	}

	/**
	 * Get multiple header of the same name
	 *
	 * @return List the values
	 * @param header
	 *            the header
	 */
	string[] getValuesList(HttpHeader header) {
		Array!(string) list;
		foreach (HttpField f; this) {
			if (f.getHeader() == header)
				list.insertBack(f.getValue());
		}
		return list.array();
	}

	/**
	 * Get multiple header of the same name
	 * 
	 * @return List the header values
	 * @param name
	 *            the case-insensitive field name
	 */
	string[] getValuesList(string name) {
		Array!(string) list;
		foreach (HttpField f; this) {
			if (f.getName().equalsIgnoreCase(name))
				list.insertBack(f.getValue());
		}
		return list.array();
	}

	/**
	 * Add comma separated values, but only if not already present.
	 * 
	 * @param header
	 *            The header to add the value(s) to
	 * @param values
	 *            The value(s) to add
	 * @return True if headers were modified
	 */
	// bool addCSV(HttpHeader header, string... values) {
	// 	QuotedCSV existing = null;
	// 	for (HttpField f : this) {
	// 		if (f.getHeader() == header) {
	// 			if (existing == null)
	// 				existing = new QuotedCSV(false);
	// 			existing.addValue(f.getValue());
	// 		}
	// 	}

	// 	string value = addCSV(existing, values);
	// 	if (value != null) {
	// 		add(header, value);
	// 		return true;
	// 	}
	// 	return false;
	// }

	/**
	 * Add comma separated values, but only if not already present.
	 * 
	 * @param name
	 *            The header to add the value(s) to
	 * @param values
	 *            The value(s) to add
	 * @return True if headers were modified
	 */
	bool addCSV(string name, string[] values...) {
		QuotedCSV existing = null;
		foreach (HttpField f; this) {
			if (f.getName().equalsIgnoreCase(name)) {
				if (existing is null)
					existing = new QuotedCSV(false);
				existing.addValue(f.getValue());
			}
		}
		string value = addCSV(existing, values);
		if (value != null) {
			add(name, value);
			return true;
		}
		return false;
	}

	protected string addCSV(QuotedCSV existing, string[] values...) {
		// remove any existing values from the new values
		bool add = true;
		if (existing !is null && !existing.isEmpty()) {
			add = false;

			for (size_t i = values.length; i-- > 0;) {
				string unquoted = QuotedCSV.unquote(values[i]);
				if (existing.getValues().contains(unquoted))
					values[i] = null;
				else
					add = true;
			}
		}

		if (add) {
			StringBuilder value = new StringBuilder();
			foreach (string v; values) {
				if (v == null)
					continue;
				if (value.length > 0)
					value.append(", ");
				value.append(v);
			}
			if (value.length > 0)
				return value.toString();
		}

		return null;
	}

	/**
	 * Get multiple field values of the same name, split as a {@link QuotedCSV}
	 *
	 * @return List the values with OWS stripped
	 * @param header
	 *            The header
	 * @param keepQuotes
	 *            True if the fields are kept quoted
	 */
	string[] getCSV(HttpHeader header, bool keepQuotes) {
		QuotedCSV values = null;
		foreach (HttpField f; _fields[0 .. _size]) {
			if (f.getHeader() == header) {
				if (values is null)
					values = new QuotedCSV(keepQuotes);
				values.addValue(f.getValue());
			}
		}
		// Array!string ar = values.getValues();
		// return inputRangeObject(values.getValues()[].array);

		return values is null ? cast(string[]) null : values.getValues().array;
	}

	/**
	 * Get multiple field values of the same name as a {@link QuotedCSV}
	 *
	 * @return List the values with OWS stripped
	 * @param name
	 *            the case-insensitive field name
	 * @param keepQuotes
	 *            True if the fields are kept quoted
	 */
	List!string getCSV(string name, bool keepQuotes) {
		QuotedCSV values = null;
		foreach (HttpField f; _fields[0 .. _size]) {
			if (f.getName().equalsIgnoreCase(name)) {
				if (values is null)
					values = new QuotedCSV(keepQuotes);
				values.addValue(f.getValue());
			}
		}
		return values is null ? null : new ArrayList!string(values.getValues().array);
		// return inputRangeObject(values.getValues()[].array);
	}

	string[] getCsvAsArray(string name, bool keepQuotes) {
		QuotedCSV values = null;
		foreach (HttpField f; _fields[0 .. _size]) {
			if (f.getName().equalsIgnoreCase(name)) {
				if (values is null)
					values = new QuotedCSV(keepQuotes);
				values.addValue(f.getValue());
			}
		}
		return values is null ? null : values.getValues().array;
		// return inputRangeObject(values.getValues()[].array);
	}

	/**
	 * Get multiple field values of the same name, split and sorted as a
	 * {@link QuotedQualityCSV}
	 *
	 * @return List the values in quality order with the q param and OWS
	 *         stripped
	 * @param header
	 *            The header
	 */
	// List!string getQualityCSV(HttpHeader header) {
	// 	QuotedQualityCSV values = null;
	// 	for (HttpField f : this) {
	// 		if (f.getHeader() == header) {
	// 			if (values == null)
	// 				values = new QuotedQualityCSV();
	// 			values.addValue(f.getValue());
	// 		}
	// 	}

	// 	return values == null ? Collections.emptyList() : values.getValues();
	// }

	/**
	 * Get multiple field values of the same name, split and sorted as a
	 * {@link QuotedQualityCSV}
	 *
	 * @return List the values in quality order with the q param and OWS
	 *         stripped
	 * @param name
	 *            the case-insensitive field name
	 */
	// List!string getQualityCSV(string name) {
	// 	QuotedQualityCSV values = null;
	// 	for (HttpField f : this) {
	// 		if (f.getName().equalsIgnoreCase(name)) {
	// 			if (values == null)
	// 				values = new QuotedQualityCSV();
	// 			values.addValue(f.getValue());
	// 		}
	// 	}
	// 	return values == null ? Collections.emptyList() : values.getValues();
	// }

	/**
	 * Get multi headers
	 *
	 * @return Enumeration of the values
	 * @param name
	 *            the case-insensitive field name
	 */
	InputRange!string getValues(string name) {
		Array!string r;

		for (int i = 0; i < _size; i++) {
			HttpField f = _fields[i];
			if (f.getName().equalsIgnoreCase(name)) {
				string v = f.getValue();
				if (!v.empty)
					r.insertBack(v);
			}
		}

		return inputRangeObject(r[].array);
	}

	void put(HttpField field) {
		bool put = false;
		for (int i = _size; i-- > 0;) {
			HttpField f = _fields[i];
			if (f.isSameName(field)) {
				if (put) {
					--_size;
					_fields[i + 1 .. _size + 1] = _fields[i .. _size];
				} else {
					_fields[i] = field;
					put = true;
				}
			}
		}
		if (!put)
			add(field);
	}

	/**
	 * Set a field.
	 *
	 * @param name
	 *            the name of the field
	 * @param value
	 *            the value of the field. If null the field is cleared.
	 */
	void put(string name, string value) {
		if (value == null)
			remove(name);
		else
			put(new HttpField(name, value));
	}

	void put(HttpHeader header, HttpHeaderValue value) {
		put(header, value.toString());
	}

	/**
	 * Set a field.
	 *
	 * @param header
	 *            the header name of the field
	 * @param value
	 *            the value of the field. If null the field is cleared.
	 */
	void put(HttpHeader header, string value) {
		if (value == null)
			remove(header);
		else
			put(new HttpField(header, value));
	}

	/**
	 * Set a field.
	 *
	 * @param name
	 *            the name of the field
	 * @param list
	 *            the List value of the field. If null the field is cleared.
	 */
	void put(string name, List!string list) {
		remove(name);
		foreach (string v; list)
			if (!v.empty)
				add(name, v);
	}

	/**
	 * Add to or set a field. If the field is allowed to have multiple values,
	 * add will add multiple headers of the same name.
	 *
	 * @param name
	 *            the name of the field
	 * @param value
	 *            the value of the field.
	 */
	void add(string name, string value) {
		HttpField field = new HttpField(name, value);
		add(field);
	}

	void add(HttpHeader header, HttpHeaderValue value) {
		add(header, value.toString());
	}

	/**
	 * Add to or set a field. If the field is allowed to have multiple values,
	 * add will add multiple headers of the same name.
	 *
	 * @param header
	 *            the header
	 * @param value
	 *            the value of the field.
	 */
	void add(HttpHeader header, string value) {
		if (value.empty)
			throw new IllegalArgumentException("The value is null for header: " ~ header.toString());

		HttpField field = new HttpField(header, value);
		add(field);
	}

	/**
	 * Remove a field.
	 *
	 * @param name
	 *            the field to remove
	 * @return the header that was removed
	 */
	HttpField remove(HttpHeader name) {

		HttpField removed = null;
		for (int i = _size; i-- > 0;) {
			HttpField f = _fields[i];
			if (f.getHeader() == name) {
				removed = f;
				--_size;
				for (int j = i; j < size; j++)
					_fields[j] = _fields[j + 1];
			}
		}
		return removed;
	}

	/**
	 * Remove a field.
	 *
	 * @param name
	 *            the field to remove
	 * @return the header that was removed
	 */
	HttpField remove(string name) {
		HttpField removed = null;
		for (int i = _size; i-- > 0;) {
			HttpField f = _fields[i];
			if (icmp(f.getName(), name) == 0) {
				removed = f;
				--_size;
				for (int j = i; j < size; j++)
					_fields[j] = _fields[j + 1];
			}
		}
		return removed;
	}

	/**
	 * Get a header as an long value. Returns the value of an integer field or
	 * -1 if not found. The case of the field name is ignored.
	 *
	 * @param name
	 *            the case-insensitive field name
	 * @return the value of the field as a long
	 * @exception NumberFormatException
	 *                If bad long found
	 */
	long getLongField(string name) {
		HttpField field = getField(name);
		return field is null ? -1L : field.getLongValue();
	}

	/**
	 * Get a header as a date value. Returns the value of a date field, or -1 if
	 * not found. The case of the field name is ignored.
	 *
	 * @param name
	 *            the case-insensitive field name
	 * @return the value of the field as a number of milliseconds since unix
	 *         epoch
	 */
	long getDateField(string name) {
		HttpField field = getField(name);
		if (field is null)
			return -1;

		string val = valueParameters(field.getValue(), null);
		if (val.empty)
			return -1;

		// TODO: Tasks pending completion -@zxp at 6/21/2018, 10:59:24 AM
		// 
		long date = SysTime.fromISOExtString(val).stdTime(); // DateParser.parseDate(val);
		if (date == -1)
			throw new IllegalArgumentException("Cannot convert date: " ~ val);
		return date;
	}

	/**
	 * Sets the value of an long field.
	 *
	 * @param name
	 *            the field name
	 * @param value
	 *            the field long value
	 */
	void putLongField(HttpHeader name, long value) {
		string v = to!string(value);
		put(name, v);
	}

	/**
	 * Sets the value of an long field.
	 *
	 * @param name
	 *            the field name
	 * @param value
	 *            the field long value
	 */
	void putLongField(string name, long value) {
		string v = to!string(value);
		put(name, v);
	}

	/**
	 * Sets the value of a date field.
	 *
	 * @param name
	 *            the field name
	 * @param date
	 *            the field date value
	 */
	void putDateField(HttpHeader name, long date) {
		// TODO: Tasks pending completion -@zxp at 6/21/2018, 10:42:44 AM
		// 
		// string d = DateGenerator.formatDate(date);
		string d = SysTime(date).toISOExtString();
		put(name, d);
	}

	/**
	 * Sets the value of a date field.
	 *
	 * @param name
	 *            the field name
	 * @param date
	 *            the field date value
	 */
	void putDateField(string name, long date) {
		// TODO: Tasks pending completion -@zxp at 6/21/2018, 11:04:46 AM
		// 
		// string d = DateGenerator.formatDate(date);		
		string d = SysTime(date).toISOExtString();
		put(name, d);
	}

	/**
	 * Sets the value of a date field.
	 *
	 * @param name
	 *            the field name
	 * @param date
	 *            the field date value
	 */
	void addDateField(string name, long date) {
		// string d = DateGenerator.formatDate(date);
		string d = SysTime(date).toISOExtString();
		add(name, d);
	}

	override size_t toHash() @trusted nothrow {
		int hash = 0;
		foreach (HttpField field; _fields[0 .. _size])
			hash += field.toHash();
		return hash;
	}

	override bool opEquals(Object o) {
		if (o is this)
			return true;

		if (!object.opEquals(this, o))
			return false;
		HttpFields that = cast(HttpFields) o;
		if (that is null)
			return false;

		// Order is not important, so we cannot rely on List.equals().
		if (size() != that.size())
			return false;

		foreach (HttpField fi; this) {
			bool isContinue = false;
			foreach (HttpField fa; that) {
				if (fi == fa) {
					isContinue = true;
					break;
				}
			}
			if (!isContinue)
				return false;
		}
		return true;
	}

	override string toString() {
		try {
			StringBuilder buffer = new StringBuilder();
			foreach (HttpField field; this) {
				if (field !is null) {
					string tmp = field.getName();
					if (tmp != null)
						buffer.append(tmp);
					buffer.append(": ");
					tmp = field.getValue();
					if (tmp != null)
						buffer.append(tmp);
					buffer.append("\r\n");
				}
			}
			buffer.append("\r\n");
			return buffer.toString();
		} catch (Exception e) {
			warningf("http fields toString exception", e);
			return e.toString();
		}
	}

	void clear() {
		_size = 0;
	}

	void add(HttpField field) {
		version(HUNT_HTTP_DEBUG) {
			infof("header: %s", field.toString());
		}

		if (field !is null) {
			if (_size == _fields.length)
				_fields = _fields.dup ~ new HttpField[_size];
			_fields[_size++] = field;
		}
	}

	void addAll(HttpFields fields) {
		for (int i = 0; i < fields._size; i++)
			add(fields._fields[i]);
	}

	/**
	 * Add fields from another HttpFields instance. Single valued fields are
	 * replaced, while all others are added.
	 *
	 * @param fields
	 *            the fields to add
	 */
	void add(HttpFields fields) {
		if (fields is null)
			return;

		// Enumeration<string> e = fields.getFieldNames();
		// while (e.hasMoreElements()) {
		// 	string name = e.nextElement();
		// 	Enumeration<string> values = fields.getValues(name);
		// 	while (values.hasMoreElements())
		// 		add(name, values.nextElement());
		// }

		auto fieldNames = fields.getFieldNames();
		foreach (string n; fieldNames) {
			auto values = fields.getValues(n);
			foreach (string v; values)
				add(n, v);
		}
	}

	/**
	 * Get field value without parameters. Some field values can have
	 * parameters. This method separates the value from the parameters and
	 * optionally populates a map with the parameters. For example:
	 *
	 * <PRE>
	 *
	 * FieldName : Value ; param1=val1 ; param2=val2
	 *
	 * </PRE>
	 *
	 * @param value
	 *            The Field value, possibly with parameters.
	 * @return The value.
	 */
	static string stripParameters(string value) {
		if (value == null)
			return null;

		int i = cast(int) value.indexOf(';');
		if (i < 0)
			return value;
		return value.substring(0, i).strip();
	}

	/**
	 * Get field value parameters. Some field values can have parameters. This
	 * method separates the value from the parameters and optionally populates a
	 * map with the parameters. For example:
	 *
	 * <PRE>
	 *
	 * FieldName : Value ; param1=val1 ; param2=val2
	 *
	 * </PRE>
	 *
	 * @param value
	 *            The Field value, possibly with parameters.
	 * @param parameters
	 *            A map to populate with the parameters, or null
	 * @return The value.
	 */
	static string valueParameters(string value, Map!(string, string) parameters) {
		if (value is null)
			return null;

		int i = cast(int) value.indexOf(';');
		if (i < 0)
			return value;
		if (parameters is null)
			return value.substring(0, i).strip();

		StringTokenizer tok1 = new QuotedStringTokenizer(value.substring(i), ";", false, true);
		while (tok1.hasMoreTokens()) {
			string token = tok1.nextToken();
			StringTokenizer tok2 = new QuotedStringTokenizer(token, "= ");
			if (tok2.hasMoreTokens()) {
				string paramName = tok2.nextToken();
				string paramVal = null;
				if (tok2.hasMoreTokens())
					paramVal = tok2.nextToken();
				parameters.put(paramName, paramVal);
			}
		}

		return value.substring(0, i).strip();
	}
}
