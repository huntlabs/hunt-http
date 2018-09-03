module hunt.http.codec.websocket.model;

import java.io.IOException;
import java.util.*;

import hunt.http.codec.websocket.utils.HeaderValueGenerator.generateHeaderValue;

class UpgradeResponseAdapter : UpgradeResponse {

    static final string SEC_WEBSOCKET_PROTOCOL = WebSocketConstants.SEC_WEBSOCKET_PROTOCOL;

    private int statusCode;
    private string statusReason;
    private Map<string, List<string>> headers = new TreeMap<>(string.CASE_INSENSITIVE_ORDER);
    private List<ExtensionConfig> extensions = new ArrayList<>();
    private bool success = false;

    override
    void addHeader(string name, string value) {
        string key = name;
        List<string> values = headers.get(key);
        if (values is null) {
            values = new ArrayList<>();
        }
        values.add(value);
        headers.put(key, values);
    }

    /**
     * Get the accepted WebSocket protocol.
     *
     * @return the accepted WebSocket protocol.
     */
    override
    string getAcceptedSubProtocol() {
        return getHeader(SEC_WEBSOCKET_PROTOCOL);
    }

    /**
     * Get the list of extensions that should be used for the websocket.
     *
     * @return the list of negotiated extensions to use.
     */
    override
    List<ExtensionConfig> getExtensions() {
        return extensions;
    }

    override
    string getHeader(string name) {
        List<string> values = getHeaders(name);
        // no value list
        if (values is null) {
            return null;
        }
        int size = values.size();
        // empty value list
        if (size <= 0) {
            return null;
        }
        // simple return
        if (size == 1) {
            return values.get(0);
        }
        return generateHeaderValue(values);
    }

    override
    Set<string> getHeaderNames() {
        return headers.keySet();
    }

    override
    Map<string, List<string>> getHeaders() {
        return headers;
    }

    override
    List<string> getHeaders(string name) {
        return headers.get(name);
    }

    override
    int getStatusCode() {
        return statusCode;
    }

    override
    string getStatusReason() {
        return statusReason;
    }

    override
    bool isSuccess() {
        return success;
    }

    /**
     * Issue a forbidden upgrade response.
     * <p>
     * This means that the websocket endpoint was valid, but the conditions to use a WebSocket resulted in a forbidden
     * access.
     * <p>
     * Use this when the origin or authentication is invalid.
     *
     * @param message the short 1 line detail message about the forbidden response
     * @throws IOException if unable to send the forbidden
     */
    override
    void sendForbidden(string message) throws IOException {
        throw new UnsupportedOperationException("Not supported");
    }

    /**
     * Set the accepted WebSocket Protocol.
     *
     * @param protocol the protocol to list as accepted
     */
    override
    void setAcceptedSubProtocol(string protocol) {
        setHeader(SEC_WEBSOCKET_PROTOCOL, protocol);
    }

    /**
     * Set the list of extensions that are approved for use with this websocket.
     * <p>
     * Notes:
     * <ul>
     * <li>Per the spec you cannot add extensions that have not been seen in the {@link UpgradeRequest}, just remove entries you don't want to use</li>
     * <li>If this is unused, or a null is passed, then the list negotiation will follow default behavior and use the complete list of extensions that are
     * available in this WebSocket server implementation.</li>
     * </ul>
     *
     * @param extensions the list of extensions to use.
     */
    override
    void setExtensions(List<ExtensionConfig> extensions) {
        this.extensions.clear();
        if (extensions !is null) {
            this.extensions.addAll(extensions);
        }
    }

    override
    void setHeader(string name, string value) {
        List<string> values = new ArrayList<>();
        values.add(value);
        headers.put(name, values);
    }

    override
    void setStatusCode(int statusCode) {
        this.statusCode = statusCode;
    }

    override
    void setStatusReason(string statusReason) {
        this.statusReason = statusReason;
    }

    override
    void setSuccess(bool success) {
        this.success = success;
    }
}
