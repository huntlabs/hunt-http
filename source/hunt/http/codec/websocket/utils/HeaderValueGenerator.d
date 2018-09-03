module hunt.http.codec.websocket.utils;

import java.util.List;

/**
 * 
 */
abstract class HeaderValueGenerator {

    static string generateHeaderValue(List<string> values) {
        // join it with commas
        bool needsDelim = false;
        StringBuilder ret = new StringBuilder();
        for (string value : values) {
            if (needsDelim) {
                ret.append(", ");
            }
            QuoteUtil.quoteIfNeeded(ret, value, QuoteUtil.ABNF_REQUIRED_QUOTING);
            needsDelim = true;
        }
        return ret.toString();
    }
}
