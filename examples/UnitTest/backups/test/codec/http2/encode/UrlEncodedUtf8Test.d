
module test.codec.http2.encode;

import hunt.http.codec.http.encode.UrlEncoded;
import hunt.http.utils.collection.MultiMap;
import hunt.http.utils.lang.Utf8Appendable;
import hunt.util.Assert;
import hunt.util.Test;

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;

public class UrlEncodedUtf8Test {

    
    public void testIncompleteSequestAtTheEnd() {
        byte[] bytes = {97, 98, 61, 99, -50};
        string test = new string(bytes, StandardCharsets.UTF_8);
        string expected = "c" ~ Utf8Appendable.REPLACEMENT;

        fromString(test, test, "ab", expected, false);
        fromInputStream(test, bytes, "ab", expected, false);
    }

    
    public void testIncompleteSequestAtTheEnd2() {
        byte[] bytes = {97, 98, 61, -50};
        string test = new string(bytes, StandardCharsets.UTF_8);
        string expected = "" ~ Utf8Appendable.REPLACEMENT;

        fromString(test, test, "ab", expected, false);
        fromInputStream(test, bytes, "ab", expected, false);

    }

    
    public void testIncompleteSequestInName() {
        byte[] bytes = {101, -50, 61, 102, 103, 38, 97, 98, 61, 99, 100};
        string test = new string(bytes, StandardCharsets.UTF_8);
        string name = "e" ~ Utf8Appendable.REPLACEMENT;
        string value = "fg";

        fromString(test, test, name, value, false);
        fromInputStream(test, bytes, name, value, false);
    }

    
    public void testIncompleteSequestInValue() {
        byte[] bytes = {101, 102, 61, 103, -50, 38, 97, 98, 61, 99, 100};
        string test = new string(bytes, StandardCharsets.UTF_8);
        string name = "ef";
        string value = "g" ~ Utf8Appendable.REPLACEMENT;

        fromString(test, test, name, value, false);
        fromInputStream(test, bytes, name, value, false);
    }

    static void fromString(string test, string s, string field, string expected, bool thrown) {
        MultiMap<string> values = new MultiMap<>();
        try {
            UrlEncoded.decodeUtf8To(s, 0, s.length, values);
            if (thrown)
                Assert.fail();
            Assert.assertEquals(test, expected, values.getString(field));
        } catch (Exception e) {
            if (!thrown)
                throw e;
        }
    }

    static void fromInputStream(string test, byte[] b, string field, string expected, bool thrown) {
        InputStream is = new ByteArrayInputStream(b);
        MultiMap<string> values = new MultiMap<>();
        try {
            UrlEncoded.decodeUtf8To(is, values, 1000000, -1);
            if (thrown)
                Assert.fail();
            Assert.assertEquals(test, expected, values.getString(field));
        } catch (Exception e) {
            if (!thrown)
                throw e;
        }
    }

}
