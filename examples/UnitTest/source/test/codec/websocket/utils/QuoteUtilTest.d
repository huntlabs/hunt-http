module test.codec.websocket.utils.QuoteUtilTest;

import hunt.util.string.QuoteUtil;

import hunt.container;
import hunt.util.Assert;
import hunt.util.exception;
import hunt.util.string;

import std.conv;
import std.exception;
import std.range;

/**
 * Test QuoteUtil
 */
class QuoteUtilTest {
    private void assertSplitAt(InputRange!string iter, string[] expectedParts...) {
        size_t len = expectedParts.length;
        for (size_t i = 0; i < len; i++) {
            string expected = expectedParts[i];
            string index = i.to!string(); 
            Assert.assertThat("Split[" ~ index ~ "].empty()", iter.empty(), (false));
            Assert.assertThat("Split[" ~ index ~ "].front()", iter.front(), (expected));
            iter.popFront();
        }
    }

    
    void testSplitAt_PreserveQuoting() {
        InputRange!string iter = QuoteUtil.splitAt("permessage-compress; method=\"foo, bar\"", ";");
        assertSplitAt(iter, "permessage-compress", "method=\"foo, bar\"");
    }

    
    void testSplitAt_PreserveQuotingWithNestedDelim() {
        InputRange!string iter = QuoteUtil.splitAt("permessage-compress; method=\"foo; x=10\"", ";");
        assertSplitAt(iter, "permessage-compress", "method=\"foo; x=10\"");
    }

    void testSplitAtAllWhitespace() {
        InputRange!string iter = QuoteUtil.splitAt("   ", "=");
        Assert.assertThat("Has Next", iter.empty(), (true));
        assertThrown!NoSuchElementException(iter.front()); // should trigger NoSuchElementException
    }

    void testSplitAtEmpty() {
        InputRange!string iter = QuoteUtil.splitAt("", "=");
        Assert.assertThat("Has Next", iter.empty(), (true));
        assertThrown!NoSuchElementException(iter.front()); // should trigger NoSuchElementException
    }

    
    void testSplitAtHelloWorld() {
        InputRange!string iter = QuoteUtil.splitAt("Hello World", " =");
        assertSplitAt(iter, "Hello", "World");
    }

    
    void testSplitAtKeyValue_Message() {
        InputRange!string iter = QuoteUtil.splitAt("method=\"foo, bar\"", "=");
        assertSplitAt(iter, "method", "foo, bar");
    }

    
    void testSplitAtQuotedDelim() {
        // test that split ignores delimiters that occur within a quoted
        // part of the sequence.
        InputRange!string iter = QuoteUtil.splitAt("A,\"B,C\",D", ",");
        assertSplitAt(iter, "A", "B,C", "D");
    }

    
    void testSplitAtSimple() {
        InputRange!string iter = QuoteUtil.splitAt("Hi", "=");
        assertSplitAt(iter, "Hi");
    }

    
    void testSplitKeyValue_Quoted() {
        InputRange!string iter = QuoteUtil.splitAt("Key = \"Value\"", "=");
        assertSplitAt(iter, "Key", "Value");
    }

    
    void testSplitKeyValue_QuotedValueList() {
        InputRange!string iter = QuoteUtil.splitAt("Fruit = \"Apple, Banana, Cherry\"", "=");
        assertSplitAt(iter, "Fruit", "Apple, Banana, Cherry");
    }

    
    void testSplitKeyValue_QuotedWithDelim() {
        InputRange!string iter = QuoteUtil.splitAt("Key = \"Option=Value\"", "=");
        assertSplitAt(iter, "Key", "Option=Value");
    }

    
    void testSplitKeyValue_Simple() {
        InputRange!string iter = QuoteUtil.splitAt("Key=Value", "=");
        assertSplitAt(iter, "Key", "Value");
    }

    
    void testSplitKeyValue_WithWhitespace() {
        InputRange!string iter = QuoteUtil.splitAt("Key = Value", "=");
        assertSplitAt(iter, "Key", "Value");
    }

    
    void testQuoteIfNeeded() {
        StringBuilder buf = new StringBuilder();
        QuoteUtil.quoteIfNeeded(buf, "key", ",");
        Assert.assertThat("key", buf.toString(), ("key"));
    }

    
    void testQuoteIfNeeded_null() {
        StringBuilder buf = new StringBuilder();
        QuoteUtil.quoteIfNeeded(buf, null, ";=");
        Assert.assertThat("<null>", buf.toString(), (""));
    }

    void testQuoteAndDequote() {
        foreach(string[] d; QuoteUtil_QuoteTest.data()) {
            QuoteUtil_QuoteTest t = new QuoteUtil_QuoteTest(d[0], d[1]);
            t.testQuoting();
            t.testDequoting();
        }
    }
}


/**
 * Test QuoteUtil.quote(), and QuoteUtil.dequote()
 */

class QuoteUtil_QuoteTest {
    static Collection!(string[]) data() {
        // The various quoting of a string
        List!(string[]) data = new ArrayList!(string[])();

        // dfmt off
        data.add(["Hi", "\"Hi\""]);
        data.add(["Hello World", "\"Hello World\""]);
        data.add(["9.0.0", "\"9.0.0\""]);
        data.add(["Something \"Special\"",
                "\"Something \\\"Special\\\"\""]);
        data.add(["A Few\n\"Good\"\tMen",
                "\"A Few\\n\\\"Good\\\"\\tMen\""]);
        // dfmt on

        return data;
    }

    private string unquoted;
    private string quoted;

    this(string unquoted, string quoted) {
        this.unquoted = unquoted;
        this.quoted = quoted;
    }

    
    void testDequoting() {
        string actual = QuoteUtil.dequote(quoted);
        actual = QuoteUtil.unescape(actual);
        Assert.assertThat(actual, (unquoted));
    }

    
    void testQuoting() {
        StringBuilder buf = new StringBuilder();
        QuoteUtil.quote(buf, unquoted);

        string actual = buf.toString();
        Assert.assertThat(actual, (quoted));
    }
}
