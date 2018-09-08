module hunt.http.codec.websocket.model.AcceptHash;


// import hunt.security.MessageDigest;
import hunt.util.exception;

import std.base64;
import std.digest.sha;

/**
 * Logic for working with the <code>Sec-WebSocket-Key</code> and <code>Sec-WebSocket-Accept</code> headers.
 * <p>
 * This is kept separate from Connection objects to facilitate difference in behavior between client and server, as well as making testing easier.
 */
class AcceptHash {
    /**
     * Globally Unique Identifier for use in WebSocket handshake within <code>Sec-WebSocket-Accept</code> and <code>Sec-WebSocket-Key</code> http headers.
     * <p>
     * See <a href="https://tools.ietf.org/html/rfc6455#section-1.3">Opening Handshake (Section 1.3)</a>
     */
    private enum const(ubyte)[] MAGIC = cast(const(ubyte)[])"258EAFA5-E914-47DA-95CA-C5AB0DC85B11";

    /**
     * Concatenate the provided key with the Magic GUID and return the Base64 encoded form.
     *
     * @param key the key to hash
     * @return the <code>Sec-WebSocket-Accept</code> header response (per opening handshake spec)
     */
    static string hashKey(string key) {
        try {
            SHA1 hash;
            hash.start();
            hash.put(cast(const(ubyte)[])key);
            hash.put(MAGIC);
            ubyte[20] result = hash.finish();
            const(char)[] encoded = Base64.encode(result);
            return cast(string)encoded;

        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }
}
