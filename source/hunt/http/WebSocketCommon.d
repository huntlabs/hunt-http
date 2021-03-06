module hunt.http.WebSocketCommon;

/**
 * 
 */
struct WebSocketConstants {
    enum string SEC_WEBSOCKET_EXTENSIONS = "Sec-WebSocket-Extensions";
    enum string SEC_WEBSOCKET_PROTOCOL = "Sec-WebSocket-Protocol";
    enum string SEC_WEBSOCKET_VERSION = "Sec-WebSocket-Version";
    enum int SPEC_VERSION = 13;
}


/**
 * Behavior for how the WebSocket should operate.
 * <p>
 * This dictated by the <a href="https://tools.ietf.org/html/rfc6455">RFC 6455</a> spec in various places, where certain behavior must be performed depending on
 * operation as a <a href="https://tools.ietf.org/html/rfc6455#section-4.1">CLIENT</a> vs a <a href="https://tools.ietf.org/html/rfc6455#section-4.2">SERVER</a>
 */
enum WebSocketBehavior {
    CLIENT, SERVER
}
