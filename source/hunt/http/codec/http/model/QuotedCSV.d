module hunt.http.codec.http.model.QuotedCSV;

import std.array;
import std.conv;
import std.container.array;

import hunt.util.Common;
import hunt.collection.StringBuffer;
import hunt.text.Common;
import hunt.text.StringBuilder;

/**
 * Implements a quoted comma separated list of values
 * in accordance with RFC7230.
 * OWS is removed and quoted characters ignored for parsing.
 *
 * @see "https://tools.ietf.org/html/rfc7230#section-3.2.6"
 * @see "https://tools.ietf.org/html/rfc7230#section-7"
 */
class QuotedCSV : Iterable!string {

    private enum State {VALUE, PARAM_NAME, PARAM_VALUE}

    protected  Array!string _values; // = new ArrayList<>();
    protected  bool _keepQuotes;

    this(string[] values...) {
        this(true, values);
    }

    this(bool keepQuotes, string[] values...) {
        _keepQuotes = keepQuotes;
        foreach (string v ; values)
            addValue(v);
    }

    /**
     * Add and parse a value string(s)
     *
     * @param value A value that may contain one or more Quoted CSV items.
     */

    void addValue(string value)
     {
        if (value.empty)
            return;

        StringBuffer buffer = new StringBuffer();

        int l = cast(int)value.length;
        State state = State.VALUE;
        bool quoted = false;
        bool sloshed = false;
        int nws_length = 0;
        int last_length = 0;
        int value_length = -1;
        int param_name = -1;
        int param_value = -1;

        for (int i = 0; i <= l; i++) {
            char c = (i == l ? 0 : value[i]);

            // Handle quoting https://tools.ietf.org/html/rfc7230#section-3.2.6
            if (quoted && c != 0) {
                if (sloshed)
                    sloshed = false;
                else {
                    switch (c) {
                        case '\\':
                            sloshed = true;
                            if (!_keepQuotes)
                                continue;
                            break;
                        case '"':
                            quoted = false;
                            if (!_keepQuotes)
                                continue;
                            break;
                        default: break;
                    }
                }

                buffer.append(c);
                nws_length = buffer.length;
                continue;
            }

            // Handle common cases
            switch (c) {
                case ' ':
                case '\t':
                    if (buffer.length > last_length) // not leading OWS
                        buffer.append(c);
                    continue;

                case '"':
                    quoted = true;
                    if (_keepQuotes) {
                        if (state == State.PARAM_VALUE && param_value < 0)
                            param_value = nws_length;
                        buffer.append(c);
                    } else if (state == State.PARAM_VALUE && param_value < 0)
                        param_value = nws_length;
                    nws_length = buffer.length;
                    continue;

                case ';':
                    buffer.setLength(nws_length); // trim following OWS
                    if (state == State.VALUE) {
                        parsedValue(buffer);
                        value_length = buffer.length;
                    } else
                        parsedParam(buffer, value_length, param_name, param_value);
                    nws_length = buffer.length;
                    param_name = param_value = -1;
                    buffer.append(c);
                    last_length = ++nws_length;
                    state = State.PARAM_NAME;
                    continue;

                case ',':
                case 0:
                    if (nws_length > 0) {
                        buffer.setLength(nws_length); // trim following OWS
                        switch (state) {
                            case State.VALUE:
                                parsedValue(buffer);
                                break;
                            case State.PARAM_NAME:
                            case State.PARAM_VALUE:
                                parsedParam(buffer, value_length, param_name, param_value);
                                break;
                            default: break;
                        }
                        _values.insertBack(buffer.toString());
                    }
                    buffer.clear();
                    last_length = 0;
                    nws_length = 0;
                    value_length = param_name = param_value = -1;
                    state = State.VALUE;
                    continue;

                case '=':
                    switch (state) {
                        case State.VALUE:
                            // It wasn't really a value, it was a param name
                            value_length = param_name = 0;
                            buffer.setLength(nws_length); // trim following OWS
                            string param = buffer.toString();
                            buffer.clear();
                            parsedValue(buffer);
                            value_length = buffer.length;
                            buffer.append(param);
                            buffer.append(c);
                            last_length = ++nws_length;
                            state = State.PARAM_VALUE;
                            continue;

                        case State.PARAM_NAME:
                            buffer.setLength(nws_length); // trim following OWS
                            buffer.append(c);
                            last_length = ++nws_length;
                            state = State.PARAM_VALUE;
                            continue;

                        case State.PARAM_VALUE:
                            if (param_value < 0)
                                param_value = nws_length;
                            buffer.append(c);
                            nws_length = buffer.length;
                            continue;

                        default: break;
                    }
                    continue;

                default: {
                    final switch (state) {
                        case State.VALUE: {
                            buffer.append(c);
                            nws_length = buffer.length;
                            continue;
                        }

                        case State.PARAM_NAME: {
                            if (param_name < 0)
                                param_name = nws_length;
                            buffer.append(c);
                            nws_length = buffer.length;
                            continue;
                        }

                        case State.PARAM_VALUE: {
                            if (param_value < 0)
                                param_value = nws_length;
                            buffer.append(c);
                            nws_length = buffer.length;
                        }
                    }
                }
            }
        }
    }

    /**
     * Called when a value has been parsed
     *
     * @param buffer Containing the trimmed value, which may be mutated
     */
    protected void parsedValue(ref StringBuffer buffer) {
    }

    /**
     * Called when a parameter has been parsed
     *
     * @param buffer      Containing the trimmed value and all parameters, which may be mutated
     * @param valueLength The length of the value
     * @param paramName   The index of the start of the parameter just parsed
     * @param paramValue  The index of the start of the parameter value just parsed, or -1
     */
    protected void parsedParam(ref StringBuffer, int valueLength, int paramName, int paramValue) {
    }

    int size() {
        return cast(int)_values.length;
    }

    bool isEmpty() {
        return _values.empty();
    }

    // List<string> getValues() {
    //     return _values;
    // }
    // ref Array!string getValues() {
    //     return _values;
    // }
    string[] getValues() {
        return _values[].array;
    }

    int opApply(scope int delegate(ref string) dg)
    {
        int result = 0;
        foreach(string v; _values)
        {
            result = dg(v);
            if(result != 0) return result;
        }
        return result;
    }

    static string unquote(string s) {
        // if (!StringUtils.hasText(s)) {
        //     return s;
        // }
        // handle trivial cases
        int l = cast(int)s.length;
        // Look for any quotes
        int i = 0;
        for (; i < l; i++) {
            char c = s[i];
            if (c == '"')
                break;
        }
        if (i == l)
            return s;

        bool quoted = true;
        bool sloshed = false;
        StringBuilder buffer = new StringBuilder();
        buffer.append(s, 0, i);
        i++;
        for (; i < l; i++) {
            char c = s[i];
            if (quoted) {
                if (sloshed) {
                    buffer.append(c);
                    sloshed = false;
                } else if (c == '"')
                    quoted = false;
                else if (c == '\\')
                    sloshed = true;
                else
                    buffer.append(c);
            } else if (c == '"')
                quoted = true;
            else
                buffer.append(c);
        }
        return buffer.toString();
    }

    override
    string toString() {
        return to!string(_values[]);
    }
}