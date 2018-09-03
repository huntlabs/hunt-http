module hunt.http.codec.websocket.model.extension.identity;

import hunt.http.codec.websocket.frame.Frame;
import hunt.http.codec.websocket.model.ExtensionConfig;
import hunt.http.codec.websocket.model.extension.AbstractExtension;
import hunt.util.functional;
import hunt.http.utils.lang.QuotedStringTokenizer;

class IdentityExtension : AbstractExtension {
    private string id;

    IdentityExtension() {
        start();
    }

    string getParam(string key) {
        return getConfig().getParameter(key, "?");
    }

    override
    string getName() {
        return "identity";
    }

    override
    void incomingError(Throwable e) {
        // pass through
        nextIncomingError(e);
    }

    override
    void incomingFrame(Frame frame) {
        // pass through
        nextIncomingFrame(frame);
    }

    override
    void outgoingFrame(Frame frame, Callback callback) {
        // pass through
        nextOutgoingFrame(frame, callback);
    }

    override
    void setConfig(ExtensionConfig config) {
        super.setConfig(config);
        StringBuilder s = new StringBuilder();
        s.append(config.getName());
        s.append("@").append(Integer.toHexString(hashCode()));
        s.append("[");
        bool delim = false;
        for (string param : config.getParameterKeys()) {
            if (delim) {
                s.append(';');
            }
            s.append(param).append('=').append(QuotedStringTokenizer.quoteIfNeeded(config.getParameter(param, ""), ";="));
            delim = true;
        }
        s.append("]");
        id = s.toString();
    }

    override
    string toString() {
        return id;
    }

    override
    protected void init() {

    }

    override
    protected void destroy() {

    }
}
