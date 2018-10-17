module test.codec.http2.model.HttpURITest;

import hunt.http.codec.http.model.HttpURI;

import hunt.util.Assert;
import hunt.lang.exception;


alias assertTrue = Assert.assertTrue;
alias assertFalse = Assert.assertFalse;
alias assertThat = Assert.assertThat;
alias assertEquals = Assert.assertEquals;

string nullValue()
{
    return null;
}

public class HttpURITest {
    
    
    public void testInvalidAddress() {
        assertInvalidURI("http://[ffff::1:8080/", "Invalid URL; no closing ']' -- should throw exception");
        assertInvalidURI("**", "only '*', not '**'");
        assertInvalidURI("*/", "only '*', not '*/'");
    }

    private void assertInvalidURI(string invalidURI, string message) {
        HttpURI uri = new HttpURI();
        try {
            uri.parse(invalidURI);
            Assert.fail(message);
        } catch (IllegalArgumentException e) {
            assertTrue(true);
        }
    }

    
    public void testParse() {
        HttpURI uri = new HttpURI();

        uri.parse("*");
        assertThat(uri.getHost(), nullValue());
        assertThat(uri.getPath(), ("*"));

        uri.parse("/foo/bar");
        assertThat(uri.getHost(), nullValue());
        assertThat(uri.getPath(), ("/foo/bar"));

        uri.parse("//foo/bar");
        assertThat(uri.getHost(), ("foo"));
        assertThat(uri.getPath(), ("/bar"));

        uri.parse("http://foo/bar");
        assertThat(uri.getHost(), ("foo"));
        assertThat(uri.getPath(), ("/bar"));
    }

    
    public void testParseRequestTarget() {
        HttpURI uri = new HttpURI();

        uri.parseRequestTarget("GET", "*");
        assertThat(uri.getHost(), nullValue());
        assertThat(uri.getPath(), ("*"));

        uri.parseRequestTarget("GET", "/foo/bar");
        assertThat(uri.getHost(), nullValue());
        assertThat(uri.getPath(), ("/foo/bar"));

        uri.parseRequestTarget("GET", "//foo/bar");
        assertThat(uri.getHost(), nullValue());
        assertThat(uri.getPath(), ("//foo/bar"));

        uri.parseRequestTarget("GET", "http://foo/bar");
        assertThat(uri.getHost(), ("foo"));
        assertThat(uri.getPath(), ("/bar"));
    }

    
    // public void testExtB() {
    //     foreach (string value ; ["a", "abcdABCD", "\u00C0", "\u697C", "\uD869\uDED5", "\uD840\uDC08"]) {
    //         HttpURI uri = new HttpURI("/path?value=" ~ URLEncoder.encode(value, "UTF-8"));

    //         MultiMap!string parameters = new MultiMap!string();
    //         uri.decodeQueryTo(parameters, StandardCharsets.UTF_8);
    //         assertEquals(value, parameters.getString("value"));
    //     }
    // }

    
    public void testAt() {
        HttpURI uri = new HttpURI("/@foo/bar");
        assertEquals("/@foo/bar", uri.getPath());
    }

    
    public void testParams() {
        HttpURI uri = new HttpURI("/foo/bar");
        assertEquals("/foo/bar", uri.getPath());
        assertEquals("/foo/bar", uri.getDecodedPath());
        assertEquals(null, uri.getParam());

        uri = new HttpURI("/foo/bar;jsessionid=12345");
        assertEquals("/foo/bar;jsessionid=12345", uri.getPath());
        assertEquals("/foo/bar", uri.getDecodedPath());
        assertEquals("jsessionid=12345", uri.getParam());

        uri = new HttpURI("/foo;abc=123/bar;jsessionid=12345");
        assertEquals("/foo;abc=123/bar;jsessionid=12345", uri.getPath());
        assertEquals("/foo/bar", uri.getDecodedPath());
        assertEquals("jsessionid=12345", uri.getParam());

        uri = new HttpURI("/foo;abc=123/bar;jsessionid=12345?name=value");
        assertEquals("/foo;abc=123/bar;jsessionid=12345", uri.getPath());
        assertEquals("/foo/bar", uri.getDecodedPath());
        assertEquals("jsessionid=12345", uri.getParam());

        uri = new HttpURI("/foo;abc=123/bar;jsessionid=12345#target");
        assertEquals("/foo;abc=123/bar;jsessionid=12345", uri.getPath());
        assertEquals("/foo/bar", uri.getDecodedPath());
        assertEquals("jsessionid=12345", uri.getParam());
    }

    
    public void testMutableURI() {
        HttpURI uri = new HttpURI("/foo/bar");
        assertEquals("/foo/bar", uri.toString());
        assertEquals("/foo/bar", uri.getPath());
        assertEquals("/foo/bar", uri.getDecodedPath());

        uri.setScheme("http");
        assertEquals("http:/foo/bar", uri.toString());
        assertEquals("/foo/bar", uri.getPath());
        assertEquals("/foo/bar", uri.getDecodedPath());

        uri.setAuthority("host", 0);
        assertEquals("http://host/foo/bar", uri.toString());
        assertEquals("/foo/bar", uri.getPath());
        assertEquals("/foo/bar", uri.getDecodedPath());

        uri.setAuthority("host", 8888);
        assertEquals("http://host:8888/foo/bar", uri.toString());
        assertEquals("/foo/bar", uri.getPath());
        assertEquals("/foo/bar", uri.getDecodedPath());

        uri.setPathQuery("/f%30%30;p0/bar;p1;p2");
        assertEquals("http://host:8888/f%30%30;p0/bar;p1;p2", uri.toString());
        assertEquals("/f%30%30;p0/bar;p1;p2", uri.getPath());
        assertEquals("/f00/bar", uri.getDecodedPath());
        assertEquals("p2", uri.getParam());
        assertEquals(null, uri.getQuery());

        uri.setPathQuery("/f%30%30;p0/bar;p1;p2?name=value");
        assertEquals("http://host:8888/f%30%30;p0/bar;p1;p2?name=value", uri.toString());
        assertEquals("/f%30%30;p0/bar;p1;p2", uri.getPath());
        assertEquals("/f00/bar", uri.getDecodedPath());
        assertEquals("p2", uri.getParam());
        assertEquals("name=value", uri.getQuery());

        uri.setQuery("other=123456");
        assertEquals("http://host:8888/f%30%30;p0/bar;p1;p2?other=123456", uri.toString());
        assertEquals("/f%30%30;p0/bar;p1;p2", uri.getPath());
        assertEquals("/f00/bar", uri.getDecodedPath());
        assertEquals("p2", uri.getParam());
        assertEquals("other=123456", uri.getQuery());
    }

    
    public void testSchemeAndOrAuthority() {
        HttpURI uri = new HttpURI("/path/info");
        assertEquals("/path/info", uri.toString());

        uri.setAuthority("host", 0);
        assertEquals("//host/path/info", uri.toString());

        uri.setAuthority("host", 8888);
        assertEquals("//host:8888/path/info", uri.toString());

        uri.setScheme("http");
        assertEquals("http://host:8888/path/info", uri.toString());

        uri.setAuthority(null, 0);
        assertEquals("http:/path/info", uri.toString());

    }

    
    public void testBasicAuthCredentials() {
        HttpURI uri = new HttpURI("http://user:password@example.com:8888/blah");
        assertEquals("http://user:password@example.com:8888/blah", uri.toString());
        assertEquals(uri.getAuthority(), "example.com:8888");
        assertEquals(uri.getUser(), "user:password");
    }
}
