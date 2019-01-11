module test.codec.http2.model.QuotedCSVTest;

import std.array;
import hunt.Assert;

import hunt.http.codec.http.model.QuotedCSV;

alias assertThat = Assert.assertThat;

public class QuotedCSVTest {
	
	public void testOWS() {
		QuotedCSV values = new QuotedCSV();
		values.addValue("  value 0.5  ;  pqy = vwz  ;  q =0.5  ,  value 1.0 ,  other ; param ");
		Assert.assertThat(values.getValues().array, Matchers.contains("value 0.5;pqy=vwz;q=0.5", "value 1.0", "other;param"));
	}

	
	public void testEmpty() {
		QuotedCSV values = new QuotedCSV();
		values.addValue(",aaaa,  , bbbb ,,cccc,");
		Assert.assertThat(values.getValues().array, Matchers.contains("aaaa", "bbbb", "cccc"));
	}

	
	public void testQuoted() {
		QuotedCSV values = new QuotedCSV();
		values.addValue("A;p=\"v\",B,\"C, D\"");
		Assert.assertThat(values.getValues().array, Matchers.contains("A;p=\"v\"", "B", "\"C, D\""));
	}

	
	public void testOpenQuote() {
		QuotedCSV values = new QuotedCSV();
		values.addValue("value;p=\"v");
		Assert.assertThat(values.getValues().array, [Matchers.contains("value;p=\"v")]);
	}

	
	public void testQuotedNoQuotes() {
		QuotedCSV values = new QuotedCSV(false);
		values.addValue("A;p=\"v\",B,\"C, D\"");
		Assert.assertThat(values.getValues().array, Matchers.contains("A;p=v", "B", "C, D"));
	}

	
	public void testOpenQuoteNoQuotes() {
		QuotedCSV values = new QuotedCSV(false);
		values.addValue("value;p=\"v");
		assertThat(values.getValues().array, [Matchers.contains("value;p=v")]);
	}

	
	public void testParamsOnly() {
		QuotedCSV values = new QuotedCSV(false);
		values.addValue("for=192.0.2.43, for=\"[2001:db8:cafe::17]\", for=unknown");
		assertThat(values.getValues().array, Matchers.contains("for=192.0.2.43", "for=[2001:db8:cafe::17]", "for=unknown"));
	}

	
	// public void testMutation() {
	// 	QuotedCSV values = new QuotedCSV(false) {

	// 		override
	// 		protected void parsedValue(StringBuffer buffer) {
	// 			if (buffer.toString().contains("DELETE")) {
	// 				string s = buffer.toString().replace("DELETE", "");
	// 				buffer.setLength(0);
	// 				buffer.append(s);
	// 			}
	// 			if (buffer.toString().contains("APPEND")) {
	// 				string s = buffer.toString().replace("APPEND", "Append") + "!";
	// 				buffer.setLength(0);
	// 				buffer.append(s);
	// 			}
	// 		}

	// 		override
	// 		protected void parsedParam(StringBuffer buffer, int valueLength, int paramName, int paramValue) {
	// 			string name = paramValue > 0 ? buffer.substring(paramName, paramValue - 1)
	// 					: buffer.substring(paramName);
	// 			if ("IGNORE".equals(name))
	// 				buffer.setLength(paramName - 1);
	// 		}

	// 	};

	// 	values.addValue("normal;param=val, testAPPENDandDELETEvalue ; n=v; IGNORE = this; x=y ");
	// 	assertThat(values.getValues().array, Matchers.contains("normal;param=val", "testAppendandvalue!;n=v;x=y"));
	// }

	
	public void testUnQuote() {
		assertThat(QuotedCSV.unquote(""), (""));
		assertThat(QuotedCSV.unquote("\"\""), (""));
		assertThat(QuotedCSV.unquote("foo"), ("foo"));
		assertThat(QuotedCSV.unquote("\"foo\""), ("foo"));
		assertThat(QuotedCSV.unquote("f\"o\"o"), ("foo"));
		assertThat(QuotedCSV.unquote("\"\\\"foo\""), ("\"foo"));
		assertThat(QuotedCSV.unquote("\\foo"), ("\\foo"));
	}

}
