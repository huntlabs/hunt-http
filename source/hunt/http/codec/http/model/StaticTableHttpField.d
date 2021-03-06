module hunt.http.codec.http.model.StaticTableHttpField;

import hunt.http.HttpField;
import hunt.http.HttpHeader;
import hunt.http.HttpMethod;

import hunt.Exceptions;

/**
*/
class StaticTableHttpField(T) :HttpField {
	private T value;

	this(HttpHeader header, string name,
			string valueString, T value) {
		super(header, name, valueString);
		static if(is(T == HttpMethod))
		{
			if (value == HttpMethod.Null)
				throw new IllegalArgumentException("");
		}
		else static if(is(T == class))
		{
			if (value is null)
				throw new IllegalArgumentException("");
		}
		this.value = value;
	}

	this(HttpHeader header, string valueString,
			T value) {
		this(header, header.asString(), valueString, value);
	}

	this(string name, string valueString, T value) {
		super(name, valueString);
		static if(is(T == HttpMethod))
		{
			if (value == HttpMethod.Null)
				throw new IllegalArgumentException("");
		}
		else static if(is(T == class))
		{
			if (value is null)
				throw new IllegalArgumentException("");
		}
		this.value = value;
	}

	T getStaticValue() {
		return value;
	}

	override
	string toString() {
		return super.toString() ~ "(evaluated)";
	}
}