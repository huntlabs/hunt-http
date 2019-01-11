module test.codec.http2.model.TestHttpField;

import hunt.Assert;

import hunt.collection.ByteBuffer;
import hunt.collection.BufferUtils;

import hunt.http.codec.http.model.HttpField;
import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.model.HttpVersion;
// import hunt.http.codec.http.hpack.HpackEncoder;

alias assertTrue = Assert.assertTrue;
alias assertFalse = Assert.assertFalse;
alias assertThat = Assert.assertThat;
alias assertEquals = Assert.assertEquals;


class TestHttpField {

	void testContainsSimple() {
		HttpField field = new HttpField("name", "SomeValue");
		assertTrue(field.contains("somevalue"));
		assertTrue(field.contains("sOmEvAlUe"));
		assertTrue(field.contains("SomeValue"));
		assertFalse(field.contains("other"));
		assertFalse(field.contains("some"));
		assertFalse(field.contains("Some"));
		assertFalse(field.contains("value"));
		assertFalse(field.contains("v"));
		assertFalse(field.contains(""));
		assertFalse(field.contains(null));
		
		field = new HttpField(HttpHeader.CONNECTION, "Upgrade, HTTP2-Settings");
		assertTrue(field.contains("Upgrade"));
		assertTrue(field.contains("HTTP2-Settings"));
	}

	
	void testCaseInsensitiveHashcode_KnownField() {
		HttpField fieldFoo1 = new HttpField("Cookie", "foo");
		HttpField fieldFoo2 = new HttpField("cookie", "foo");

		// assertThat("Field hashcodes are case insensitive", fieldFoo1.toHash(), fieldFoo2.toHash());
	}

	
	void testCaseInsensitiveHashcode_UnknownField() {
		HttpField fieldFoo1 = new HttpField("X-Foo", "bar");
		HttpField fieldFoo2 = new HttpField("x-foo", "bar");

		// assertThat("Field hashcodes are case insensitive", fieldFoo1.toHash(), fieldFoo2.toHash());
	}

	
	void testContainsList() {
		HttpField field = new HttpField("name", ",aaa,Bbb,CCC, ddd , e e, \"\\\"f,f\\\"\", ");
		assertTrue(field.contains("aaa"));
		assertTrue(field.contains("bbb"));
		assertTrue(field.contains("ccc"));
		assertTrue(field.contains("Aaa"));
		assertTrue(field.contains("Bbb"));
		assertTrue(field.contains("Ccc"));
		assertTrue(field.contains("AAA"));
		assertTrue(field.contains("BBB"));
		assertTrue(field.contains("CCC"));
		assertTrue(field.contains("ddd"));
		assertTrue(field.contains("e e"));
		assertTrue(field.contains("\"f,f\""));
		assertFalse(field.contains(""));
		assertFalse(field.contains("aa"));
		assertFalse(field.contains("bb"));
		assertFalse(field.contains("cc"));
		assertFalse(field.contains(null));
	}

	
	void testQualityContainsList() {
		HttpField field;

		field = new HttpField("name", "yes");
		assertTrue(field.contains("yes"));
		assertFalse(field.contains("no"));

		field = new HttpField("name", ",yes,");
		assertTrue(field.contains("yes"));
		assertFalse(field.contains("no"));

		field = new HttpField("name", "other,yes,other");
		assertTrue(field.contains("yes"));
		assertFalse(field.contains("no"));

		field = new HttpField("name", "other,  yes  ,other");
		assertTrue(field.contains("yes"));
		assertFalse(field.contains("no"));

		field = new HttpField("name", "other,  y s  ,other");
		assertTrue(field.contains("y s"));
		assertFalse(field.contains("no"));

		field = new HttpField("name", "other,  \"yes\"  ,other");
		assertTrue(field.contains("yes"));
		assertFalse(field.contains("no"));

		field = new HttpField("name", "other,  \"\\\"yes\\\"\"  ,other");
		assertTrue(field.contains("\"yes\""));
		assertFalse(field.contains("no"));

		field = new HttpField("name", ";no,yes,;no");
		assertTrue(field.contains("yes"));
		assertFalse(field.contains("no"));

		field = new HttpField("name", "no;q=0,yes;q=1,no; q = 0");
		assertTrue(field.contains("yes"));
		assertFalse(field.contains("no"));

		field = new HttpField("name", "no;q=0.0000,yes;q=0.0001,no; q = 0.00000");
		assertTrue(field.contains("yes"));
		assertFalse(field.contains("no"));

		field = new HttpField("name", "no;q=0.0000,Yes;Q=0.0001,no; Q = 0.00000");
		assertTrue(field.contains("yes"));
		assertFalse(field.contains("no"));

	}
	
	void testValues() {
		string[] values = new HttpField("name", "value").getValues();
		assertEquals(1, values.length);
		assertEquals("value", values[0]);

		values = new HttpField("name", "a,b,c").getValues();
		assertEquals(3, values.length);
		assertEquals("a", values[0]);
		assertEquals("b", values[1]);
		assertEquals("c", values[2]);

		values = new HttpField("name", "a,\"x,y,z\",c").getValues();
		assertEquals(3, values.length);
		assertEquals("a", values[0]);
		assertEquals("x,y,z", values[1]);
		assertEquals("c", values[2]);

		values = new HttpField("name", "a,\"x,\\\"p,q\\\",z\",c").getValues();
		assertEquals(3, values.length);
		assertEquals("a", values[0]);
		assertEquals("x,\"p,q\",z", values[1]); 
		assertEquals("c", values[2]);

	}

	// TODO: Tasks pending completion -@zxp at 6/25/2018, 1:35:44 PM
	// 
	// void testCachedField() {
	// 	PreEncodedHttpField field = new PreEncodedHttpField(HttpHeader.ACCEPT, "something");
	// 	ByteBuffer buf = BufferUtils.allocate(256);
	// 	BufferUtils.clearToFill(buf);
	// 	field.putTo(buf, HttpVersion.HTTP_1_0);
	// 	BufferUtils.flipToFlush(buf, 0);
	// 	string s = BufferUtils.toString(buf);

	// 	assertEquals("Accept: something\r\n", s);
	// }
}
