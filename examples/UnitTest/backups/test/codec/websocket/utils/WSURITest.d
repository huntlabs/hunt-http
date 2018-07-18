module test.codec.websocket.utils;

import hunt.http.codec.websocket.utils.WSURI;
import hunt.util.Assert;
import hunt.util.Test;

import java.net.URI;
import java.net.URISyntaxException;



public class WSURITest {
    private void assertURI(URI actual, URI expected) {
        writeln(actual.getPort() ~ ", " ~ expected.getPort());
        Assert.assertThat(actual.toASCIIString(), is(expected.toASCIIString()));
    }

    
    public void testHttpsToHttps() throws URISyntaxException {
        assertURI(WSURI.toHttp(URI.create("https://localhost/")), URI.create("https://localhost/"));
    }

    
    public void testHttpsToWss() throws URISyntaxException {
        assertURI(WSURI.toWebsocket(URI.create("https://localhost/")), URI.create("wss://localhost/"));
    }

    
    public void testHttpToHttp() throws URISyntaxException {
        assertURI(WSURI.toHttp(URI.create("http://localhost/")), URI.create("http://localhost/"));
    }

    
    public void testHttpToWs() throws URISyntaxException {
        assertURI(WSURI.toWebsocket(URI.create("http://localhost/")), URI.create("ws://localhost/"));
        assertURI(WSURI.toWebsocket(URI.create("http://localhost:8080/deeper/")), URI.create("ws://localhost:8080/deeper/"));
        assertURI(WSURI.toWebsocket("http://localhost/"), URI.create("ws://localhost/"));
        assertURI(WSURI.toWebsocket("http://localhost/", null), URI.create("ws://localhost/"));
        assertURI(WSURI.toWebsocket("http://localhost/", "a=b"), URI.create("ws://localhost/?a=b"));
    }

    
    public void testWssToHttps() throws URISyntaxException {
        assertURI(WSURI.toHttp(URI.create("wss://localhost/")), URI.create("https://localhost/"));
    }

    
    public void testWssToWss() throws URISyntaxException {
        assertURI(WSURI.toWebsocket(URI.create("wss://localhost/")), URI.create("wss://localhost/"));
    }

    
    public void testWsToHttp() throws URISyntaxException {
        assertURI(WSURI.toHttp(URI.create("ws://localhost/")), URI.create("http://localhost/"));
    }

    
    public void testWsToWs() throws URISyntaxException {
        assertURI(WSURI.toWebsocket(URI.create("ws://localhost/")), URI.create("ws://localhost/"));
    }

}
