module test.codec.http2.hpack.HpackTest;

import hunt.http.codec.http.hpack.HpackContext;
import hunt.http.codec.http.hpack.HpackDecoder;
import hunt.http.codec.http.hpack.HpackEncoder;
import hunt.http.codec.http.model;
// import hunt.http.codec.http.model.MetaData;
import hunt.container.BufferUtils;

import hunt.util.Assert;
import hunt.util.string;

import hunt.container.ByteBuffer;

import hunt.logging;
import std.datetime;


alias assertTrue = Assert.assertTrue;
alias assertFalse = Assert.assertFalse;
alias assertThat = Assert.assertThat;
alias assertEquals = Assert.assertEquals;
alias assertNull = Assert.assertNull;

alias Response = MetaData.Response;

class HpackTest {
    static HttpField ServerHunt; 
    static HttpField XPowerHunt; 
    static HttpField Date; 

    static this()
    {
        ServerHunt = new PreEncodedHttpField(HttpHeader.SERVER, "Hunt");
        XPowerHunt = new PreEncodedHttpField(HttpHeader.X_POWERED_BY, "Hunt"); 
        Date = new PreEncodedHttpField(HttpHeader.DATE, DateGenerator.formatDate(Clock.currTime));
    }

    
    void encodeDecodeResponseTest() {
        HttpField field1 = new HttpField(HttpHeader.C_STATUS, "200");
		HttpField field2 = new HttpField(HttpHeader.C_STATUS, "200");
        assert(field1.toHash() == field2.toHash());

        HpackEncoder encoder = new HpackEncoder();
        HpackDecoder decoder = new HpackDecoder(4096, 8192);
        ByteBuffer buffer = BufferUtils.allocate(16 * 1024);

        HttpFields fields0 = new HttpFields();
        // fields0.add(Date);
        fields0.add(HttpHeader.CONTENT_TYPE, "text/html");
        fields0.add(HttpHeader.CONTENT_LENGTH, "1024");
        fields0.add(new HttpField(HttpHeader.CONTENT_ENCODING, cast(string) null));
        fields0.add(ServerHunt);
        fields0.add(XPowerHunt);
        fields0.add(Date);
        fields0.add(HttpHeader.SET_COOKIE, "abcdefghijklmnopqrstuvwxyz");
        fields0.add("custom-key", "custom-value");
        Response original0 = new MetaData.Response(HttpVersion.HTTP_2, 200, fields0);
        // trace(original0.toString());

        foreach(HttpField h; original0.iterator)
        // foreach(HttpField h;  original0)
        {
            trace(h.toString);
        }

	    BufferUtils.clearToFill(buffer);
        encoder.encode(buffer, original0);
        BufferUtils.flipToFlush(buffer, 0);
        
        tracef("position=%d, limit=%d, remaining=%d", buffer.position(), buffer.limit(), buffer.remaining());
        tracef("encoding result: %(%02X %)", buffer.array()[0.. buffer.limit()+8]);

        MetaData d = decoder.decode(buffer); 
        Response decoded0 = cast(Response) d;
        original0.getFields().put(new HttpField(HttpHeader.CONTENT_ENCODING, ""));
        assertMetadataSame(original0, decoded0);

        // Same again?
        BufferUtils.clearToFill(buffer);
        encoder.encode(buffer, original0);
        BufferUtils.flipToFlush(buffer, 0);
        Response decoded0b = cast(Response) decoder.decode(buffer);

        assertMetadataSame(original0, decoded0b);

        HttpFields fields1 = new HttpFields();
        fields1.add(HttpHeader.CONTENT_TYPE, "text/plain");
        fields1.add(HttpHeader.CONTENT_LENGTH, "1234");
        fields1.add(HttpHeader.CONTENT_ENCODING, " ");
        fields1.add(ServerHunt);
        fields1.add(XPowerHunt);
        fields1.add(Date);
        fields1.add("Custom-Key", "Other-Value");
        Response original1 = new MetaData.Response(HttpVersion.HTTP_2, 200, fields1);

        // Same again?
        BufferUtils.clearToFill(buffer);
        encoder.encode(buffer, original1);
        BufferUtils.flipToFlush(buffer, 0);
        Response decoded1 = cast(Response) decoder.decode(buffer);

        assertMetadataSame(original1, decoded1);
        Assert.assertEquals("custom-key", decoded1.getFields().getField("Custom-Key").getName());
    }

    
    void encodeDecodeTooLargeTest() {
        HpackEncoder encoder = new HpackEncoder();
        HpackDecoder decoder = new HpackDecoder(4096, 164);
        ByteBuffer buffer = BufferUtils.allocate(16 * 1024);

        HttpFields fields0 = new HttpFields();
        fields0.add("1234567890", "1234567890123456789012345678901234567890");
        fields0.add("Cookie", "abcdeffhijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQR");
        MetaData original0 = new MetaData(HttpVersion.HTTP_2, fields0);

        BufferUtils.clearToFill(buffer);
        encoder.encode(buffer, original0);
        BufferUtils.flipToFlush(buffer, 0);
        MetaData decoded0 = cast(MetaData) decoder.decode(buffer);

        assertMetadataSame(original0, decoded0);

        HttpFields fields1 = new HttpFields();
        fields1.add("1234567890", "1234567890123456789012345678901234567890");
        fields1.add("Cookie", "abcdeffhijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQR");
        fields1.add("x", "y");
        MetaData original1 = new MetaData(HttpVersion.HTTP_2, fields1);

        BufferUtils.clearToFill(buffer);
        encoder.encode(buffer, original1);
        BufferUtils.flipToFlush(buffer, 0);
        try {
            decoder.decode(buffer);
            Assert.fail();
        } catch (BadMessageException e) {
            assertEquals(HttpStatus.REQUEST_HEADER_FIELDS_TOO_LARGE_431, e.getCode());
        }
    }

    
    void evictReferencedFieldTest() {
        HpackEncoder encoder = new HpackEncoder(200, 200);
        HpackDecoder decoder = new HpackDecoder(200, 1024);
        ByteBuffer buffer = BufferUtils.allocate(16 * 1024);

        HttpFields fields0 = new HttpFields();
        fields0.add("123456789012345678901234567890123456788901234567890", "value");
        fields0.add("foo", "abcdeffhijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQR");
        MetaData original0 = new MetaData(HttpVersion.HTTP_2, fields0);

        BufferUtils.clearToFill(buffer);
        encoder.encode(buffer, original0);
        BufferUtils.flipToFlush(buffer, 0);
        MetaData decoded0 = cast(MetaData) decoder.decode(buffer);

        assertEquals(2, encoder.getHpackContext().size());
        assertEquals(2, decoder.getHpackContext().size());
        assertEquals("123456789012345678901234567890123456788901234567890", encoder.getHpackContext().get(HpackContext.STATIC_TABLE.length + 1).getHttpField().getName());
        assertEquals("foo", encoder.getHpackContext().get(HpackContext.STATIC_TABLE.length + 0).getHttpField().getName());

        assertMetadataSame(original0, decoded0);

        HttpFields fields1 = new HttpFields();
        fields1.add("123456789012345678901234567890123456788901234567890", "other_value");
        fields1.add("x", "y");
        MetaData original1 = new MetaData(HttpVersion.HTTP_2, fields1);

        BufferUtils.clearToFill(buffer);
        encoder.encode(buffer, original1);
        BufferUtils.flipToFlush(buffer, 0);
        MetaData decoded1 = cast(MetaData) decoder.decode(buffer);
        assertMetadataSame(original1, decoded1);

        assertEquals(2, encoder.getHpackContext().size());
        assertEquals(2, decoder.getHpackContext().size());
        assertEquals("x", encoder.getHpackContext().get(HpackContext.STATIC_TABLE.length + 0).getHttpField().getName());
        assertEquals("foo", encoder.getHpackContext().get(HpackContext.STATIC_TABLE.length + 1).getHttpField().getName());
    }

    private void assertMetadataSame(MetaData.Response expected, MetaData.Response actual) {
        assertThat("Response.status", actual.getStatus(), (expected.getStatus()));
        assertThat("Response.reason", actual.getReason(), (expected.getReason()));
        assertMetadataSame(cast(MetaData) expected, cast(MetaData) actual);
    }

    private void assertMetadataSame(MetaData expected, MetaData actual) {
        assertThat("Metadata.contentLength", actual.getContentLength(), (expected.getContentLength()));
        assertThat("Metadata.version" ~ ".version", actual.getHttpVersion(), (expected.getHttpVersion()));
        assertHttpFieldsSame("Metadata.fields", expected.getFields(), actual.getFields());
    }

    private void assertHttpFieldsSame(string msg, HttpFields expected, HttpFields actual) {
        assertThat(msg ~ ".size", actual.size(), (expected.size()));

        foreach (HttpField actualField ; actual) {
            if ("DATE".equalsIgnoreCase(actualField.getName())) {
                // skip comparison on Date, as these values can often differ by 1 second
                // during testing.
                continue;
            }
            assertThat(msg ~ ".contains(" ~ actualField.toString() ~ ")", expected.contains(actualField), (true));
        }
    }
}
