module test.codec.http2.encode.TestPredefinedHTTP1Response;

import hunt.util.Assert;
// import hunt.util.Test;

import hunt.http.codec.http.encode.PredefinedHTTP1Response;

import std.stdio;

/**
 */
class TestPredefinedHTTP1Response {

    
    void testH2c() {
        // writeln(PredefinedHTTP1Response.H2C_BYTES.length);
        Assert.assertThat(PredefinedHTTP1Response.H2C_BYTES.length, (71));
        // writeln(cast(string)(PredefinedHTTP1Response.H2C_BYTES));
        Assert.assertThat(cast(string)(PredefinedHTTP1Response.H2C_BYTES), (
                "HTTP/1.1 101 Switching Protocols\r\n" ~
                        "Connection: Upgrade\r\n" ~
                        "Upgrade: h2c\r\n\r\n"));
    }

    
    void testContinue100() {
        // writeln(PredefinedHTTP1Response.CONTINUE_100_BYTES.length);
        Assert.assertThat(cast(int)PredefinedHTTP1Response.CONTINUE_100_BYTES.length, (25));
        // writeln(cast(string)(PredefinedHTTP1Response.CONTINUE_100_BYTES));
        Assert.assertThat(cast(string)(PredefinedHTTP1Response.CONTINUE_100_BYTES), ("HTTP/1.1 100 Continue\r\n\r\n"));
    }
}
