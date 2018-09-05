module hunt.http.codec.websocket.model.ExtensionConfig;

import hunt.http.codec.websocket.utils.QuoteUtil;

import hunt.container;
import hunt.util.exception;
import hunt.util.string;

import std.conv;
import std.range;

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
    // static List<ExtensionConfig> parseEnum(Enumeration<string> valuesEnum) {
    //     List<ExtensionConfig> configs = new ArrayList<>();

    //     if (valuesEnum !is null) {
    //         while (valuesEnum.hasMoreElements()) {
    //             Iterator<string> extTokenIter = QuoteUtil.splitAt(valuesEnum.nextElement(), ",");
    //             while (extTokenIter.hasNext()) {
    //                 string extToken = extTokenIter.next();
    //                 configs.add(ExtensionConfig.parse(extToken));
    //             }
    //         }
    //     }

    //     return configs;
    // }

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
    // static string toHeaderValue(List<ExtensionConfig> configs) {
    //     if ((configs is null) || (configs.isEmpty())) {
    //         return null;
    //     }
    //     StringBuilder parameters = new StringBuilder();
    //     bool needsDelim = false;
    //     for (ExtensionConfig ext : configs) {
    //         if (needsDelim) {
    //             parameters.append(", ");
    //         }
    //         parameters.append(ext.getParameterizedName());
    //         needsDelim = true;
    //     }
    //     return parameters.toString();
    // }

    private string name;
    private Map!(string, string) parameters;

    /**
     * Copy constructor
     *
     * @param copy the extension config to copy
     */
    this(ExtensionConfig copy) {
        this.name = copy.name;
        // this.parameters = new HashMap<>();
        // this.parameters.putAll(copy.parameters);
    }

    this(string parameterizedName) {
        implementationMissing(false);
        // Iterator<string> extListIter = QuoteUtil.splitAt(parameterizedName, ";");
        // this.name = extListIter.next();
        this.parameters = new HashMap!(string, string)();

        // now for parameters
        // while (extListIter.hasNext()) {
        //     string extParam = extListIter.next();
        //     Iterator<string> extParamIter = QuoteUtil.splitAt(extParam, "=");
        //     string key = extParamIter.next().trim();
        //     string value = null;
        //     if (extParamIter.hasNext()) {
        //         value = extParamIter.next();
        //     }
        //     parameters.put(key, value);
        // }
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
    final void init(ExtensionConfig other) {
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

    // override
    // string toString() {
    //     return getParameterizedName();
    // }
}
