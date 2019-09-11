module test.codec.websocket.model;

import hunt.http.codec.websocket.model.AcceptHash;
import hunt.http.utils.codec.B64Code;
import hunt.util.TypeUtils;
import hunt.Assert;
import hunt.util.Test;



public class AcceptHashTest {
    
    public void testHash() {
        byte key[] = ConverterUtils.fromHexString("00112233445566778899AABBCCDDEEFF");
        Assert.assertThat("Key size", key.length, is(16));

        // what the client sends
        string clientKey = string.valueOf(B64Code.encode(key));
        // what the server responds with
        string serverHash = AcceptHash.hashKey(clientKey);

        // how the client validates
        Assert.assertThat(serverHash, is("mVL6JKtNRC4tluIaFAW2hhMffgE="));
    }

    /**
     * Test of values present in RFC-6455.
     * <p>
     * Note: client key bytes are "7468652073616d706c65206e6f6e6365"
     */
    
    public void testRfcHashExample() {
        // What the client sends in the RFC
        string clientKey = "dGhlIHNhbXBsZSBub25jZQ==";

        // What the server responds with
        string serverAccept = AcceptHash.hashKey(clientKey);
        string expectedHash = "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=";

        Assert.assertThat(serverAccept, is(expectedHash));
    }
}
