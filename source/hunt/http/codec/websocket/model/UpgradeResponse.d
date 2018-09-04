module hunt.http.codec.websocket.model.UpgradeResponse;


import hunt.container;
import hunt.util.exception;

/**
 * The HTTP Upgrade to WebSocket Response
 */
interface UpgradeResponse {
    /**
     * Add a header value to the response.
     *
     * @param name  the header name
     * @param value the header value
     */
    void addHeader(string name, string value);

    /**
     * Get the accepted WebSocket protocol.
     *
     * @return the accepted WebSocket protocol.
     */
    string getAcceptedSubProtocol();

    /**
     * Get the list of extensions that should be used for the websocket.
     *
     * @return the list of negotiated extensions to use.
     */
    List!(ExtensionConfig) getExtensions();

    /**
     * Get a header value
     *
     * @param name the header name
     * @return the value (null if header doesn't exist)
     */
    string getHeader(string name);

    /**
     * Get the header names
     *
     * @return the set of header names
     */
    Set!(string) getHeaderNames();

    /**
     * Get the headers map
     *
     * @return the map of headers
     */
    Map!(string, List!(string)) getHeaders();

    /**
     * Get the multi-value header value
     *
     * @param name the header name
     * @return the list of values (null if header doesn't exist)
     */
    List!(string) getHeaders(string name);

    /**
     * Get the HTTP Response Status Code
     *
     * @return the status code
     */
    int getStatusCode();

    /**
     * Get the HTTP Response Status Reason
     *
     * @return the HTTP Response status reason
     */
    string getStatusReason();

    /**
     * Test if upgrade response is successful.
     * !(p)
     * Merely notes if the response was sent as a WebSocket Upgrade,
     * or was failed (resulting in no upgrade handshake)
     *
     * @return true if upgrade response was generated, false if no upgrade response was generated
     */
    bool isSuccess();

    /**
     * Issue a forbidden upgrade response.
     * !(p)
     * This means that the websocket endpoint was valid, but the conditions to use a WebSocket resulted in a forbidden
     * access.
     * !(p)
     * Use this when the origin or authentication is invalid.
     *
     * @param message the short 1 line detail message about the forbidden response
     * @throws IOException if unable to send the forbidden
     */
    void sendForbidden(string message);

    /**
     * Set the accepted WebSocket Protocol.
     *
     * @param protocol the protocol to list as accepted
     */
    void setAcceptedSubProtocol(string protocol);

    /**
     * Set the list of extensions that are approved for use with this websocket.
     * !(p)
     * Notes:
     * !(ul)
     * !(li)Per the spec you cannot add extensions that have not been seen in the {@link UpgradeRequest}, just remove
     * entries you don't want to use!(/li)
     * !(li)If this is unused, or a null is passed, then the list negotiation will follow default behavior and use the
     * complete list of extensions that are
     * available in this WebSocket server implementation.!(/li)
     * !(/ul)
     *
     * @param extensions the list of extensions to use.
     */
    void setExtensions(List!(ExtensionConfig) extensions);

    /**
     * Set a header
     * !(p)
     * Overrides previous value of header (if set)
     *
     * @param name  the header name
     * @param value the header value
     */
    void setHeader(string name, string value);

    /**
     * Set the HTTP Response status code
     *
     * @param statusCode the status code
     */
    void setStatusCode(int statusCode);

    /**
     * Set the HTTP Response status reason phrase
     * !(p)
     * Note, not all implementation of UpgradeResponse can support this feature
     *
     * @param statusReason the status reason phrase
     */
    void setStatusReason(string statusReason);

    /**
     * Set the success of the upgrade response.
     * !(p)
     *
     * @param success true to indicate a response to the upgrade handshake was sent, false to indicate no upgrade
     *                response was sent
     */
    void setSuccess(bool success);
}
