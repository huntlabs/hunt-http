module test.codec.websocket.utils;

import hunt.http.codec.websocket.utils.QuoteUtil;
import hunt.util.Assert;
import hunt.util.Test;

import java.util.Iterator;
import java.util.NoSuchElementException;


import hunt.util.Assert.assertThat;

/**
 * Test QuoteUtil
 */
public class QuoteUtilTest {
    private void assertSplitAt(Iterator<string> iter, string... expectedParts) {
        int len = expectedParts.length;
        for (int i = 0; i < len; i++) {
            string expected = expectedParts[i];
            Assert.assertThat("Split[" ~ i ~ "].hasNext()", iter.hasNext(), is(true));
            Assert.assertThat("Split[" ~ i ~ "].next()", iter.next(), is(expected));
        }
    }

    
    public void testSplitAt_PreserveQuoting() {
        Iterator<string> iter = QuoteUtil.splitAt("permessage-compress; method=\"foo, bar\"", ";");
        assertSplitAt(iter, "permessage-compress", "method=\"foo, bar\"");
    }

    
    public void testSplitAt_PreserveQuotingWithNestedDelim() {
        Iterator<string> iter = QuoteUtil.splitAt("permessage-compress; method=\"foo; x=10\"", ";");
        assertSplitAt(iter, "permessage-compress", "method=\"foo; x=10\"");
    }

    (expected = NoSuchElementException.class)
    public void testSplitAtAllWhitespace() {
        Iterator<string> iter = QuoteUtil.splitAt("   ", "=");
        Assert.assertThat("Has Next", iter.hasNext(), is(false));
        iter.next(); // should trigger NoSuchElementException
    }

    (expected = NoSuchElementException.class)
    public void testSplitAtEmpty() {
        Iterator<string> iter = QuoteUtil.splitAt("", "=");
        Assert.assertThat("Has Next", iter.hasNext(), is(false));
        iter.next(); // should trigger NoSuchElementException
    }

    
    public void testSplitAtHelloWorld() {
        Iterator<string> iter = QuoteUtil.splitAt("Hello World", " =");
        assertSplitAt(iter, "Hello", "World");
    }

    
    public void testSplitAtKeyValue_Message() {
        Iterator<string> iter = QuoteUtil.splitAt("method=\"foo, bar\"", "=");
        assertSplitAt(iter, "method", "foo, bar");
    }

    
    public void testSplitAtQuotedDelim() {
        // test that split ignores delimiters that occur within a quoted
        // part of the sequence.
        Iterator<string> iter = QuoteUtil.splitAt("A,\"B,C\",D", ",");
        assertSplitAt(iter, "A", "B,C", "D");
    }

    
    public void testSplitAtSimple() {
        Iterator<string> iter = QuoteUtil.splitAt("Hi", "=");
        assertSplitAt(iter, "Hi");
    }

    
    public void testSplitKeyValue_Quoted() {
        Iterator<string> iter = QuoteUtil.splitAt("Key = \"Value\"", "=");
        assertSplitAt(iter, "Key", "Value");
    }

    
    public void testSplitKeyValue_QuotedValueList() {
        Iterator<string> iter = QuoteUtil.splitAt("Fruit = \"Apple, Banana, Cherry\"", "=");
        assertSplitAt(iter, "Fruit", "Apple, Banana, Cherry");
    }

    
    public void testSplitKeyValue_QuotedWithDelim() {
        Iterator<string> iter = QuoteUtil.splitAt("Key = \"Option=Value\"", "=");
        assertSplitAt(iter, "Key", "Option=Value");
    }

    
    public void testSplitKeyValue_Simple() {
        Iterator<string> iter = QuoteUtil.splitAt("Key=Value", "=");
        assertSplitAt(iter, "Key", "Value");
    }

    
    public void testSplitKeyValue_WithWhitespace() {
        Iterator<string> iter = QuoteUtil.splitAt("Key = Value", "=");
        assertSplitAt(iter, "Key", "Value");
    }

    
    public void testQuoteIfNeeded() {
        StringBuilder buf = new StringBuilder();
        QuoteUtil.quoteIfNeeded(buf, "key", ",");
        assertThat("key", buf.toString(), is("key"));
    }

    
    public void testQuoteIfNeeded_null() {
        StringBuilder buf = new StringBuilder();
        QuoteUtil.quoteIfNeeded(buf, null, ";=");
        assertThat("<null>", buf.toString(), is(""));
    }
}
