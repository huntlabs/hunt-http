module test.codec.http2.model;

import hunt.http.codec.http.model.QuotedQualityCSV;

import hunt.Assert;
import hunt.util.Test;


import hunt.Assert.assertThat;

public class QuotedQualityCSVTest {
    
    public void test7231_5_3_2_example1() {
        QuotedQualityCSV values = new QuotedQualityCSV();
        values.addValue(" audio/*; q=0.2, audio/basic");
        Assert.assertThat(values, Matchers.contains("audio/basic", "audio/*"));
    }

    
    public void test7231_5_3_2_example2() {
        QuotedQualityCSV values = new QuotedQualityCSV();
        values.addValue("text/plain; q=0.5, text/html,");
        values.addValue("text/x-dvi; q=0.8, text/x-c");
        Assert.assertThat(values, Matchers.contains("text/html", "text/x-c", "text/x-dvi", "text/plain"));
    }

    
    public void test7231_5_3_2_example3() {
        QuotedQualityCSV values = new QuotedQualityCSV();
        values.addValue("text/*, text/plain, text/plain;format=flowed, */*");

        // Note this sort is only on quality and not the most specific type as per 5.3.2
        Assert.assertThat(values, Matchers.contains("text/*", "text/plain", "text/plain;format=flowed", "*/*"));
    }

    
    public void test7231_5_3_2_example3_most_specific() {
        QuotedQualityCSV values = new QuotedQualityCSV(QuotedQualityCSV.MOST_SPECIFIC);
        values.addValue("text/*, text/plain, text/plain;format=flowed, */*");

        Assert.assertThat(values, Matchers.contains("text/plain;format=flowed", "text/plain", "text/*", "*/*"));
    }

    
    public void test7231_5_3_2_example4() {
        QuotedQualityCSV values = new QuotedQualityCSV();
        values.addValue("text/*;q=0.3, text/html;q=0.7, text/html;level=1,");
        values.addValue("text/html;level=2;q=0.4, */*;q=0.5");
        Assert.assertThat(values, Matchers.contains(
                "text/html;level=1",
                "text/html",
                "*/*",
                "text/html;level=2",
                "text/*"
        ));
    }

    
    public void test7231_5_3_4_example1() {
        QuotedQualityCSV values = new QuotedQualityCSV();
        values.addValue("compress, gzip");
        values.addValue("");
        values.addValue("*");
        values.addValue("compress;q=0.5, gzip;q=1.0");
        values.addValue("gzip;q=1.0, identity; q=0.5, *;q=0");

        Assert.assertThat(values, Matchers.contains(
                "compress",
                "gzip",
                "*",
                "gzip",
                "gzip",
                "compress",
                "identity"
        ));
    }

    
    public void testOWS() {
        QuotedQualityCSV values = new QuotedQualityCSV();
        values.addValue("  value 0.5  ;  p = v  ;  q =0.5  ,  value 1.0 ");
        Assert.assertThat(values, Matchers.contains(
                "value 1.0",
                "value 0.5;p=v"));
    }

    
    public void testEmpty() {
        QuotedQualityCSV values = new QuotedQualityCSV();
        values.addValue(",aaaa,  , bbbb ,,cccc,");
        Assert.assertThat(values, Matchers.contains(
                "aaaa",
                "bbbb",
                "cccc"));
    }

    
    public void testQuoted() {
        QuotedQualityCSV values = new QuotedQualityCSV();
        values.addValue("  value 0.5  ;  p = \"v  ;  q = \\\"0.5\\\"  ,  value 1.0 \"  ");
        Assert.assertThat(values, Matchers.contains(
                "value 0.5;p=\"v  ;  q = \\\"0.5\\\"  ,  value 1.0 \""));
    }

    
    public void testOpenQuote() {
        QuotedQualityCSV values = new QuotedQualityCSV();
        values.addValue("value;p=\"v");
        Assert.assertThat(values, Matchers.contains(
                "value;p=\"v"));
    }

    
    public void testQuotedQuality() {
        QuotedQualityCSV values = new QuotedQualityCSV();
        values.addValue("  value 0.5  ;  p = v  ;  q = \"0.5\"  ,  value 1.0 ");
        Assert.assertThat(values, Matchers.contains(
                "value 1.0",
                "value 0.5;p=v"));
    }

    
    public void testBadQuality() {
        QuotedQualityCSV values = new QuotedQualityCSV();
        values.addValue("value0.5;p=v;q=0.5,value1.0,valueBad;q=X");
        Assert.assertThat(values, Matchers.contains(
                "value1.0",
                "value0.5;p=v"));
    }

    
    public void testBad() {
        QuotedQualityCSV values = new QuotedQualityCSV();


        // None of these should throw exceptions
        values.addValue(null);
        values.addValue("");

        values.addValue(";");
        values.addValue("=");
        values.addValue(",");

        values.addValue(";");
        values.addValue(";=");
        values.addValue(";,");
        values.addValue("=;");
        values.addValue("==");
        values.addValue("=,");
        values.addValue(",;");
        values.addValue(",=");
        values.addValue(",,");

        values.addValue(";;");
        values.addValue(";=");
        values.addValue(";,");
        values.addValue(";=;");
        values.addValue(";==");
        values.addValue(";=,");
        values.addValue(";,;");
        values.addValue(";,=");
        values.addValue(";,,");

        values.addValue("=;");
        values.addValue("=;=");
        values.addValue("=;,");
        values.addValue("==;");
        values.addValue("===");
        values.addValue("==,");
        values.addValue("=,;");
        values.addValue("=,=");
        values.addValue("=,,");

        values.addValue(",;");
        values.addValue(",;=");
        values.addValue(",;,");
        values.addValue(",=;");
        values.addValue(",==");
        values.addValue(",=,");
        values.addValue(",,;");
        values.addValue(",,=");
        values.addValue(",,,");

        values.addValue("x;=1");
        values.addValue("=1");
        values.addValue("q=x");
        values.addValue("q=0");
        values.addValue("q=");
        values.addValue("q=,");
        values.addValue("q=;");

    }

    /* ------------------------------------------------------------ */

    private static final string[] preferBrotli = {"br", "gzip"};
    private static final string[] preferGzip = {"gzip", "br"};
    private static final string[] noFormats = {};

    
    public void testFirefoxContentEncodingWithBrotliPreference() {
        QuotedQualityCSV values = new QuotedQualityCSV(preferBrotli);
        values.addValue("gzip, deflate, br");
        assertThat(values, contains("br", "gzip", "deflate"));
    }

    
    public void testFirefoxContentEncodingWithGzipPreference() {
        QuotedQualityCSV values = new QuotedQualityCSV(preferGzip);
        values.addValue("gzip, deflate, br");
        assertThat(values, contains("gzip", "br", "deflate"));
    }

    
    public void testFirefoxContentEncodingWithNoPreference() {
        QuotedQualityCSV values = new QuotedQualityCSV(noFormats);
        values.addValue("gzip, deflate, br");
        assertThat(values, contains("gzip", "deflate", "br"));
    }

    
    public void testChromeContentEncodingWithBrotliPreference() {
        QuotedQualityCSV values = new QuotedQualityCSV(preferBrotli);
        values.addValue("gzip, deflate, sdch, br");
        assertThat(values, contains("br", "gzip", "deflate", "sdch"));
    }

    
    public void testComplexEncodingWithGzipPreference() {
        QuotedQualityCSV values = new QuotedQualityCSV(preferGzip);
        values.addValue("gzip;q=0.9, identity;q=0.1, *;q=0.01, deflate;q=0.9, sdch;q=0.7, br;q=0.9");
        assertThat(values, contains("gzip", "br", "deflate", "sdch", "identity", "*"));
    }

    
    public void testComplexEncodingWithBrotliPreference() {
        QuotedQualityCSV values = new QuotedQualityCSV(preferBrotli);
        values.addValue("gzip;q=0.9, identity;q=0.1, *;q=0, deflate;q=0.9, sdch;q=0.7, br;q=0.99");
        assertThat(values, contains("br", "gzip", "deflate", "sdch", "identity"));
    }

    
    public void testStarEncodingWithGzipPreference() {
        QuotedQualityCSV values = new QuotedQualityCSV(preferGzip);
        values.addValue("br, *");
        assertThat(values, contains("*", "br"));
    }

    
    public void testStarEncodingWithBrotliPreference() {
        QuotedQualityCSV values = new QuotedQualityCSV(preferBrotli);
        values.addValue("gzip, *");
        assertThat(values, contains("*", "gzip"));
    }


    
    public void testSameQuality() {
        QuotedQualityCSV values = new QuotedQualityCSV();
        values.addValue("one;q=0.5,two;q=0.5,three;q=0.5");
        Assert.assertThat(values.getValues(), Matchers.contains("one", "two", "three"));
    }

    
    public void testNoQuality() {
        QuotedQualityCSV values = new QuotedQualityCSV();
        values.addValue("one,two;,three;x=y");
        Assert.assertThat(values.getValues(), Matchers.contains("one", "two", "three;x=y"));
    }
}
