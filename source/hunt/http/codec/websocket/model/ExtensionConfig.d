module hunt.http.codec.websocket.model.ExtensionConfig;

import hunt.http.codec.websocket.utils.QuoteUtil;

import hunt.container;
import hunt.util.exception;
import hunt.util.string;

import std.array;
import std.container.array;
import std.conv;
import std.range;
import std.string;

/**
 * Represents an Extension Configuration, as seen during the connection Handshake process.
 */
class ExtensionConfig {
    /**
     * Parse a single parameterized name.
     *
     * @param parameterizedName the parameterized name
     * @return the ExtensionConfig
     */
    static ExtensionConfig parse(string parameterizedName) {
        return new ExtensionConfig(parameterizedName);
    }

    /**
     * Parse enumeration of <code>Sec-WebSocket-Extensions</code> header values into a {@link ExtensionConfig} list
     *
     * @param valuesEnum the raw header values enum
     * @return the list of extension configs
     */
    static Array!ExtensionConfig parseEnum(InputRange!string valuesEnum) {
        Array!(ExtensionConfig) configs;

        if (valuesEnum !is null) {
            foreach(string value; valuesEnum) {
                InputRange!string extTokenIter = QuoteUtil.splitAt(value, ",");
                foreach(string extToken; extTokenIter) {
                    // configs.add(ExtensionConfig.parse(extToken));
                    configs.insert(ExtensionConfig.parse(extToken));
                }
            }
        }

        return configs;
    }

    /**
     * Parse 1 or more raw <code>Sec-WebSocket-Extensions</code> header values into a {@link ExtensionConfig} list
     *
     * @param rawSecWebSocketExtensions the raw header values
     * @return the list of extension configs
     */
    // static List<ExtensionConfig> parseList(string... rawSecWebSocketExtensions) {
    //     List<ExtensionConfig> configs = new ArrayList<>();

    //     for (string rawValue : rawSecWebSocketExtensions) {
    //         Iterator<string> extTokenIter = QuoteUtil.splitAt(rawValue, ",");
    //         while (extTokenIter.hasNext()) {
    //             string extToken = extTokenIter.next();
    //             configs.add(ExtensionConfig.parse(extToken));
    //         }
    //     }

    //     return configs;
    // }

    /**
     * Convert a list of {@link ExtensionConfig} to a header value
     *
     * @param configs the list of extension configs
     * @return the header value (null if no configs present)
     */
    static string toHeaderValue(ExtensionConfig[] configs) {
        if (configs.empty()) {
            return null;
        }
        Appender!(string)  parameters;
        bool needsDelim = false;
        foreach (ExtensionConfig ext ; configs) {
            if (needsDelim) {
                parameters.put(", ");
            }
            parameters.put(ext.getParameterizedName());
            needsDelim = true;
        }
        return parameters.data;
    }

    private string name;
    private Map!(string, string) parameters;

    /**
     * Copy constructor
     *
     * @param copy the extension config to copy
     */
    this(ExtensionConfig copy) {
        this.name = copy.name;
        this.parameters = new HashMap!(string, string)();
        this.parameters.putAll(copy.parameters);
    }

    this(string parameterizedName) {
        InputRange!string extListIter = QuoteUtil.splitAt(parameterizedName, ";");
        this.name = extListIter.front();
        this.parameters = new HashMap!(string, string)();

        // now for parameters
        extListIter.popFront();
        while (!extListIter.empty()) {
            string extParam = extListIter.front();
            InputRange!string extParamIter = QuoteUtil.splitAt(extParam, "=");

            string key = extParamIter.front().strip();
            extParamIter.popFront();

            string value = null;
            if (!extParamIter.empty()) {
                value = extParamIter.front();
            }
            parameters.put(key, value);
            extListIter.popFront();
        }
    }

    string getName() {
        return name;
    }

    final int getParameter(string key, int defValue) {
        string val = parameters.get(key);
        if (val is null) {
            return defValue;
        }
        return to!int(val);
    }

    final string getParameter(string key, string defValue) {
        string val = parameters.get(key);
        if (val is null) {
            return defValue;
        }
        return val;
    }

    final string getParameterizedName() {
        StringBuilder str = new StringBuilder();
        str.append(name);
        foreach (string param ; parameters.byKey) {
            str.append(';');
            str.append(param);
            string value = parameters.get(param);
            if (value !is null) {
                str.append('=');
                QuoteUtil.quoteIfNeeded(str, value, ";=");
            }
        }
        return str.toString();
    }

    final InputRange!string getParameterKeys() {
        return parameters.byKey;
    }

    /**
     * Return parameters found in request URI.
     *
     * @return the parameter map
     */
    final Map!(string, string) getParameters() {
        return parameters;
    }

    /**
     * Initialize the parameters on this config from the other configuration.
     *
     * @param other the other configuration.
     */
    final void initilize(ExtensionConfig other) {
        this.parameters.clear();
        this.parameters.putAll(other.parameters);
    }

    final void setParameter(string key) {
        parameters.put(key, null);
    }

    final void setParameter(string key, int value) {
        parameters.put(key, value.to!string());
    }

    final void setParameter(string key, string value) {
        parameters.put(key, value);
    }

    override
    string toString() {
        return getParameterizedName();
    }
}
