module test.codec.http2.model.MimeTypesTest;

import hunt.http.codec.http.model.AcceptMimeType;
import hunt.http.codec.http.model.MimeTypes;


import hunt.container.List;

import hunt.util.Assert;
import hunt.lang.exception;

alias assertTrue = Assert.assertTrue;
alias assertFalse = Assert.assertFalse;
alias assertThat = Assert.assertThat;
alias assertEquals = Assert.assertEquals;
alias assertNotNull = Assert.assertNotNull;
alias assertNull = Assert.assertNull;

class MimeTypesTest {
    
    void testGetMimeByExtension_Gzip() {
        assertMimeTypeByExtension("application/gzip", "test.gz");
    }

    
    void testGetMimeByExtension_Png() {
        assertMimeTypeByExtension("image/png", "test.png");
        assertMimeTypeByExtension("image/png", "TEST.PNG");
        assertMimeTypeByExtension("image/png", "Test.Png");
    }

    
    void testGetMimeByExtension_Png_MultiDot() {
        assertMimeTypeByExtension("image/png", "org.eclipse.jetty.Logo.png");
    }

    
    void testGetMimeByExtension_Png_DeepPath() {
        assertMimeTypeByExtension("image/png", "/org/eclipse/jetty/Logo.png");
    }

    
    void testGetMimeByExtension_Text() {
        assertMimeTypeByExtension("text/plain", "test.txt");
        assertMimeTypeByExtension("text/plain", "TEST.TXT");
    }

    
    void testGetMimeByExtension_NoExtension() {
        MimeTypes mimetypes = new MimeTypes();
        string contentType = mimetypes.getMimeByExtension("README");
        assertNull(contentType);
    }

    private void assertMimeTypeByExtension(string expectedMimeType, string filename) {
        MimeTypes mimetypes = new MimeTypes();
        string contentType = mimetypes.getMimeByExtension(filename);
        string prefix = "MimeTypes.getMimeByExtension(" ~ filename ~ ")";
        assertNotNull(prefix, contentType);
        assertEquals(prefix, expectedMimeType, contentType);
    }

    private void assertCharsetFromContentType(string contentType, string expectedCharset) {
        assertThat("getCharsetFromContentType(\"" ~ contentType ~ "\")",
                MimeTypes.getCharsetFromContentType(contentType), expectedCharset);
    }

    
    void testCharsetFromContentType() {
        assertCharsetFromContentType("foo/bar;charset=abc;some=else", "abc");
        assertCharsetFromContentType("foo/bar;charset=abc", "abc");
        assertCharsetFromContentType("foo/bar ; charset = abc", "abc");
        assertCharsetFromContentType("foo/bar ; charset = abc ; some=else", "abc");
        assertCharsetFromContentType("foo/bar;other=param;charset=abc;some=else", "abc");
        assertCharsetFromContentType("foo/bar;other=param;charset=abc", "abc");
        assertCharsetFromContentType("foo/bar other = param ; charset = abc", "abc");
        assertCharsetFromContentType("foo/bar other = param ; charset = abc ; some=else", "abc");
        assertCharsetFromContentType("foo/bar other = param ; charset = abc", "abc");
        assertCharsetFromContentType("foo/bar other = param ; charset = \"abc\" ; some=else", "abc");
        assertCharsetFromContentType("foo/bar", null);
        assertCharsetFromContentType("foo/bar;charset=uTf8", "utf-8");
        assertCharsetFromContentType("foo/bar;other=\"charset=abc\";charset=uTf8", "utf-8");
        assertCharsetFromContentType("application/pdf; charset=UTF-8", "utf-8");
        assertCharsetFromContentType("application/pdf;; charset=UTF-8", "utf-8");
        assertCharsetFromContentType("application/pdf;;; charset=UTF-8", "utf-8");
        assertCharsetFromContentType("application/pdf;;;; charset=UTF-8", "utf-8");
        assertCharsetFromContentType("text/html;charset=utf-8", "utf-8");
    }

    
    void testContentTypeWithoutCharset() {
        assertEquals("foo/bar;some=else", MimeTypes.getContentTypeWithoutCharset("foo/bar;charset=abc;some=else"));
        assertEquals("foo/bar", MimeTypes.getContentTypeWithoutCharset("foo/bar;charset=abc"));
        assertEquals("foo/bar", MimeTypes.getContentTypeWithoutCharset("foo/bar ; charset = abc"));
        assertEquals("foo/bar;some=else", MimeTypes.getContentTypeWithoutCharset("foo/bar ; charset = abc ; some=else"));
        assertEquals("foo/bar;other=param;some=else", MimeTypes.getContentTypeWithoutCharset("foo/bar;other=param;charset=abc;some=else"));
        assertEquals("foo/bar;other=param", MimeTypes.getContentTypeWithoutCharset("foo/bar;other=param;charset=abc"));
        assertEquals("foo/bar ; other = param", MimeTypes.getContentTypeWithoutCharset("foo/bar ; other = param ; charset = abc"));
        assertEquals("foo/bar ; other = param;some=else", MimeTypes.getContentTypeWithoutCharset("foo/bar ; other = param ; charset = abc ; some=else"));
        assertEquals("foo/bar ; other = param", MimeTypes.getContentTypeWithoutCharset("foo/bar ; other = param ; charset = abc"));
        assertEquals("foo/bar ; other = param;some=else", MimeTypes.getContentTypeWithoutCharset("foo/bar ; other = param ; charset = \"abc\" ; some=else"));
        assertEquals("foo/bar", MimeTypes.getContentTypeWithoutCharset("foo/bar"));
        assertEquals("foo/bar", MimeTypes.getContentTypeWithoutCharset("foo/bar;charset=uTf8"));
        assertEquals("foo/bar;other=\"charset=abc\"", MimeTypes.getContentTypeWithoutCharset("foo/bar;other=\"charset=abc\";charset=uTf8"));
        assertEquals("text/html", MimeTypes.getContentTypeWithoutCharset("text/html;charset=utf-8"));
    }

    
    void testAcceptMimeTypes() {
        AcceptMimeType[] list = MimeTypes.parseAcceptMIMETypes("text/plain; q=0.9, text/html");
        Assert.assertThat(list.length, 2);
        Assert.assertThat(list[0].getParentType(), "text");
        Assert.assertThat(list[0].getChildType(), "html");
        Assert.assertThat(list[0].getQuality(), 1.0f);
        Assert.assertThat(list[1].getParentType(), "text");
        Assert.assertThat(list[1].getChildType(), "plain");
        Assert.assertThat(list[1].getQuality(), 0.9f);

        list = MimeTypes.parseAcceptMIMETypes("text/plain, text/html");
        Assert.assertThat(list.length, 2);
        Assert.assertThat(list[0].getParentType(), "text");
        Assert.assertThat(list[0].getChildType(), "plain");
        Assert.assertThat(list[1].getParentType(), "text");
        Assert.assertThat(list[1].getChildType(), "html");

        list = MimeTypes.parseAcceptMIMETypes("text/plain");
        Assert.assertThat(list.length, 1);
        Assert.assertThat(list[0].getParentType(), "text");
        Assert.assertThat(list[0].getChildType(), "plain");

        list = MimeTypes.parseAcceptMIMETypes("*/*; q=0.8, text/plain; q=0.9, text/html, */json");
        Assert.assertThat(list.length, 4);
        
        // import hunt.logging;
        // foreach(AcceptMimeType t; list) 
        //     tracef("%s, %f", t.getParentType(), t.getQuality());

        Assert.assertThat(list[0].getParentType(), "text");
        Assert.assertThat(list[0].getChildType(), "html");
        Assert.assertThat(list[0].getQuality(), 1.0f);
        Assert.assertThat(list[0].getMatchType(), AcceptMimeMatchType.EXACT);

        Assert.assertThat(list[1].getParentType(), "*");
        Assert.assertThat(list[1].getChildType(), "json");
        Assert.assertThat(list[1].getQuality(), 1.0f);
        Assert.assertThat(list[1].getMatchType(), AcceptMimeMatchType.CHILD);

        Assert.assertThat(list[2].getParentType(), "text");
        Assert.assertThat(list[2].getChildType(), "plain");
        Assert.assertThat(list[2].getQuality(), 0.9f);
        Assert.assertThat(list[2].getMatchType(), AcceptMimeMatchType.EXACT);

        Assert.assertThat(list[3].getParentType(), "*");
        Assert.assertThat(list[3].getChildType(), "*");
        Assert.assertThat(list[3].getQuality(), 0.8f);
        Assert.assertThat(list[3].getMatchType(), AcceptMimeMatchType.ALL);
    }
}
