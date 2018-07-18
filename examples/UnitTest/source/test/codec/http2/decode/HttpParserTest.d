module test.codec.http2.decode.HttpParserTest;

import hunt.http.codec.http.decode.HttpParser;
import hunt.http.codec.http.model;
// import hunt.http.codec.http.model.HttpComplianceSection;

import hunt.util.Assert;
import hunt.util.exception;
import hunt.util.Charset;

import hunt.container.BufferUtils;
import hunt.container.ByteBuffer;
import hunt.container.ArrayList;
import hunt.container.List;

import kiss.logger;

import std.conv;
import std.range;
import std.stdio;

alias State = HttpParser.State;

/**
*/
class HttpParserTest {

    private string _host;
    private int _port;
    private string _bad;
    private string _content;
    private string _methodOrVersion;
    private string _uriOrStatus;
    private string _versionOrReason;
    private List!HttpField _fields; // = new ArrayList!HttpField();
    private List!HttpField _trailers; // = new ArrayList!HttpField();
    private string[] _hdr;
    private string[] _val;
    private int _headers;
    private bool _early;
    private bool _headerCompleted;
    private bool _messageCompleted;
    private List!HttpComplianceSection _complianceViolation; // = new ArrayList!HttpComplianceSection();

    this()
    {
        _fields = new ArrayList!HttpField();
        _trailers = new ArrayList!HttpField();
        _complianceViolation = new ArrayList!HttpComplianceSection();
    }


    // static this() {
    //     // HttpCompliance.CUSTOM0.sections().remove(HttpComplianceSection.NO_WS_AFTER_FIELD_NAME);
    // }

    /**
     * Parse until {@link State#END} state.
     * If the parser is already in the END state, then it is {@link HttpParser#reset()} and re-parsed.
     *
     * @param parser The parser to test
     * @param buffer the buffer to parse
     * @throws IllegalStateException If the buffers have already been partially parsed.
     */
    static void parseAll(HttpParser parser, ByteBuffer buffer) {
        if (parser.isState(State.END))
            parser.reset();
        if (!parser.isState(State.START))
            throw new IllegalStateException("!START");

        // continue parsing
        int remaining = buffer.remaining();
        while (!parser.isState(State.END) && remaining > 0) {
            int was_remaining = remaining;
            parser.parseNext(buffer);
            remaining = buffer.remaining();
            if (remaining == was_remaining)
                break;
        }
    }


    // void testResponseParse0_temp() {
    //     ByteBuffer buffer = BufferUtils.toBuffer(
    //             "HTTP/1.1 200 Correct\r\n"
    //                     ~ "Content-Length: 10\r\n"
    //                     ~ "Content-Type: text/plain\r\n"
    //                     ~ "\r\n"
    //                     ~ "0123456789\r\n");

    //     HttpParser.ResponseHandler handler = new Handler();
    //     HttpParser parser = new HttpParser(handler);
    //     parser.parseNext(buffer);
    //     Assert.assertEquals("HTTP/1.1", _methodOrVersion);
    //     Assert.assertEquals("200", _uriOrStatus);
    //     Assert.assertEquals("Correct", _versionOrReason);
    //     trace("content: ", _content);
    //     Assert.assertEquals(10, _content.length);
    //     Assert.assertTrue(_headerCompleted);
    //     Assert.assertTrue(_messageCompleted);
    // }
    
    void HttpMethodTest() {
        Assert.assertNull(HttpMethod.lookAheadGet(BufferUtils.toBuffer("Wibble ")));
        Assert.assertNull(HttpMethod.lookAheadGet(BufferUtils.toBuffer("GET")));
        Assert.assertNull(HttpMethod.lookAheadGet(BufferUtils.toBuffer("MO")));

        Assert.assertEquals(HttpMethod.GET, HttpMethod.lookAheadGet(BufferUtils.toBuffer("GET ")));
        Assert.assertEquals(HttpMethod.MOVE, HttpMethod.lookAheadGet(BufferUtils.toBuffer("MOVE ")));

        ByteBuffer b = BufferUtils.allocate(128);
        BufferUtils.append(b, BufferUtils.toBuffer("GET"));
        Assert.assertNull(HttpMethod.lookAheadGet(b));

        BufferUtils.append(b, BufferUtils.toBuffer(" "));
        Assert.assertEquals(HttpMethod.GET, HttpMethod.lookAheadGet(b));
    }

    
    void testLineParse_Mock_IP() {
        ByteBuffer buffer = BufferUtils.toBuffer("POST /mock/127.0.0.1 HTTP/1.1\r\n" ~ "\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parseAll(parser, buffer);
        Assert.assertEquals("POST", _methodOrVersion);
        Assert.assertEquals("/mock/127.0.0.1", _uriOrStatus);
        Assert.assertEquals("HTTP/1.1", _versionOrReason);
        Assert.assertEquals(-1, _headers);
    }

    
    void testLineParse0() {
        ByteBuffer buffer = BufferUtils.toBuffer("POST /foo HTTP/1.0\r\n" ~ "\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parseAll(parser, buffer);
        Assert.assertEquals("POST", _methodOrVersion);
        Assert.assertEquals("/foo", _uriOrStatus);
        Assert.assertEquals("HTTP/1.0", _versionOrReason);
        Assert.assertEquals(-1, _headers);
    }

    // FIXME: Needing refactor or cleanup -@zxp at 7/1/2018, 4:07:07 PM
    // 
    void testLineParse1_RFC2616() {
        ByteBuffer buffer = BufferUtils.toBuffer("GET /999\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler, HttpCompliance.RFC2616_LEGACY);
        parseAll(parser, buffer);

        // Assert.assertNull(_bad);  
        Assert.assertEquals("GET", _methodOrVersion);
        Assert.assertEquals("/999", _uriOrStatus);
        Assert.assertEquals("HTTP/0.9", _versionOrReason);
        Assert.assertEquals(-1, _headers);
        _complianceViolation.contains(HttpComplianceSection.NO_HTTP_0_9);
    }

    
    void testLineParse1() {
        ByteBuffer buffer = BufferUtils.toBuffer("GET /999\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parseAll(parser, buffer);
        Assert.assertEquals("HTTP/0.9 not supported", _bad);
        Assert.assertTrue(_complianceViolation.isEmpty());
    }

    
    void testLineParse2_RFC2616() {
        ByteBuffer buffer = BufferUtils.toBuffer("POST /222  \r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler, HttpCompliance.RFC2616_LEGACY);
        parseAll(parser, buffer);

        // Assert.assertNull(_bad);
        Assert.assertEquals("POST", _methodOrVersion);
        Assert.assertEquals("/222", _uriOrStatus);
        Assert.assertEquals("HTTP/0.9", _versionOrReason);
        Assert.assertEquals(-1, _headers);
        // Assert.assertTrue(_complianceViolation.contains(HttpComplianceSection.NO_HTTP_0_9));
    }

    
    void testLineParse2() {
        ByteBuffer buffer = BufferUtils.toBuffer("POST /222  \r\n");

        _versionOrReason = null;
        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parseAll(parser, buffer);
        Assert.assertEquals("HTTP/0.9 not supported", _bad);
        Assert.assertTrue(_complianceViolation.isEmpty());
    }

    
    void testLineParse3() {
        ByteBuffer buffer = BufferUtils.toBuffer("POST /fo\u0690 HTTP/1.0\r\n" ~ "\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parseAll(parser, buffer);
        Assert.assertEquals("POST", _methodOrVersion);
        Assert.assertEquals("/fo\u0690", _uriOrStatus);
        Assert.assertEquals("HTTP/1.0", _versionOrReason);
        Assert.assertEquals(-1, _headers);
    }

    
    void testLineParse4() {
        ByteBuffer buffer = BufferUtils.toBuffer("POST /foo?param=\u0690 HTTP/1.0\r\n" ~ "\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parseAll(parser, buffer);
        Assert.assertEquals("POST", _methodOrVersion);
        Assert.assertEquals("/foo?param=\u0690", _uriOrStatus);
        Assert.assertEquals("HTTP/1.0", _versionOrReason);
        Assert.assertEquals(-1, _headers);
    }

    
    void testLongURLParse() {
        ByteBuffer buffer = BufferUtils.toBuffer("POST /123456789abcdef/123456789abcdef/123456789abcdef/123456789abcdef/123456789abcdef/123456789abcdef/123456789abcdef/123456789abcdef/123456789abcdef/123456789abcdef/123456789abcdef/123456789abcdef/123456789abcdef/123456789abcdef/123456789abcdef/123456789abcdef/ HTTP/1.0\r\n" ~ "\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parseAll(parser, buffer);
        Assert.assertEquals("POST", _methodOrVersion);
        Assert.assertEquals("/123456789abcdef/123456789abcdef/123456789abcdef/123456789abcdef/123456789abcdef/123456789abcdef/123456789abcdef/123456789abcdef/123456789abcdef/123456789abcdef/123456789abcdef/123456789abcdef/123456789abcdef/123456789abcdef/123456789abcdef/123456789abcdef/", _uriOrStatus);
        Assert.assertEquals("HTTP/1.0", _versionOrReason);
        Assert.assertEquals(-1, _headers);
    }

    
    void testConnect() {
        ByteBuffer buffer = BufferUtils.toBuffer("CONNECT 192.168.1.2:80 HTTP/1.1\r\n" ~ "\r\n");
        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parseAll(parser, buffer);
        Assert.assertEquals("CONNECT", _methodOrVersion);
        Assert.assertEquals("192.168.1.2:80", _uriOrStatus);
        Assert.assertEquals("HTTP/1.1", _versionOrReason);
        Assert.assertEquals(-1, _headers);
    }

    
    void testSimple() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET / HTTP/1.0\r\n" ~
                        "Host: localhost\r\n" ~
                        "Connection: close\r\n" ~
                        "\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parseAll(parser, buffer);

        Assert.assertTrue(_headerCompleted);
        Assert.assertTrue(_messageCompleted);
        Assert.assertEquals("GET", _methodOrVersion);
        Assert.assertEquals("/", _uriOrStatus);
        Assert.assertEquals("HTTP/1.0", _versionOrReason);
        Assert.assertEquals("Host", _hdr[0]);
        Assert.assertEquals("localhost", _val[0]);
        Assert.assertEquals("Connection", _hdr[1]);
        Assert.assertEquals("close", _val[1]);
        Assert.assertEquals(1, _headers);
    }

    
    void testFoldedField2616() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET / HTTP/1.0\r\n" ~
                        "Host: localhost\r\n" ~
                        "Name: value\r\n" ~
                        " extra\r\n" ~
                        "Name2: \r\n" ~
                        "\tvalue2\r\n" ~
                        "\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler, HttpCompliance.RFC2616_LEGACY);
        parseAll(parser, buffer);

        // Assert.assertTrue(_bad.empty);
        Assert.assertEquals("Host", _hdr[0]);
        Assert.assertEquals("localhost", _val[0]);
        Assert.assertEquals(2, _headers);
        Assert.assertEquals("Name", _hdr[1]);
        Assert.assertEquals("value extra", _val[1]);
        Assert.assertEquals("Name2", _hdr[2]);
        Assert.assertEquals("value2", _val[2]);
        // FIXME: Needing refactor or cleanup -@zxp at 6/29/2018, 5:44:18 PM
        // 
        // Assert.assertThat(_complianceViolation, contains(NO_FIELD_FOLDING, NO_FIELD_FOLDING));
    }

    
    void testFoldedField7230() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET / HTTP/1.0\r\n" ~
                        "Host: localhost\r\n" ~
                        "Name: value\r\n" ~
                        " extra\r\n" ~
                        "\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler, 4096, HttpCompliance.RFC7230_LEGACY);
        parseAll(parser, buffer);

        Assert.assertTrue(!_bad.empty);
        Assert.assertContain(_bad, "Header Folding");
        Assert.assertTrue(_complianceViolation.isEmpty());
    }

    
    void testWhiteSpaceInName() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET / HTTP/1.0\r\n" ~
                        "Host: localhost\r\n" ~
                        "N ame: value\r\n" ~
                        "\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler, 4096, HttpCompliance.RFC7230_LEGACY);
        parseAll(parser, buffer);

        Assert.assertTrue(!_bad.empty);
        Assert.assertContain(_bad, "Illegal character");
    }

    
    void testWhiteSpaceAfterName() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET / HTTP/1.0\r\n" ~
                        "Host: localhost\r\n" ~
                        "Name : value\r\n" ~
                        "\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler, 4096, HttpCompliance.RFC7230_LEGACY);
        parseAll(parser, buffer);

        Assert.assertTrue(!_bad.empty);
        Assert.assertContain(_bad, "Illegal character");
    }

    
    void testNoValue() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET / HTTP/1.0\r\n" ~
                        "Host: localhost\r\n" ~
                        "Name0: \r\n" ~
                        "Name1:\r\n" ~
                        "\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parseAll(parser, buffer);

        Assert.assertTrue(_headerCompleted);
        Assert.assertTrue(_messageCompleted);
        Assert.assertEquals("GET", _methodOrVersion);
        Assert.assertEquals("/", _uriOrStatus);
        Assert.assertEquals("HTTP/1.0", _versionOrReason);
        Assert.assertEquals("Host", _hdr[0]);
        Assert.assertEquals("localhost", _val[0]);
        Assert.assertEquals("Name0", _hdr[1]);
        Assert.assertEquals("", _val[1]);
        Assert.assertEquals("Name1", _hdr[2]);
        Assert.assertEquals("", _val[2]);
        Assert.assertEquals(2, _headers);
    }

    
    // void testSpaceinNameCustom0() {
    //     ByteBuffer buffer = BufferUtils.toBuffer(
    //             "GET / HTTP/1.0\r\n" ~
    //                     "Host: localhost\r\n" ~
    //                     "Name with space: value\r\n" ~
    //                     "Other: value\r\n" ~
    //                     "\r\n");

    //     HttpParser.RequestHandler handler = new Handler();
    //     HttpParser parser = new HttpParser(handler, HttpCompliance.CUSTOM0);
    //     parseAll(parser, buffer);

    //     Assert.assertContain(_bad, "Illegal character");
    //     Assert.assertTrue(_complianceViolation.contains(HttpComplianceSection.NO_WS_AFTER_FIELD_NAME));
    //     // Assert.assertThat(_complianceViolation, contains(HttpComplianceSection.NO_WS_AFTER_FIELD_NAME));
    // }

    
    // void testNoColonCustom0() {
    //     ByteBuffer buffer = BufferUtils.toBuffer(
    //             "GET / HTTP/1.0\r\n" ~
    //                     "Host: localhost\r\n" ~
    //                     "Name \r\n" ~
    //                     "Other: value\r\n" ~
    //                     "\r\n");

    //     HttpParser.RequestHandler handler = new Handler();
    //     HttpParser parser = new HttpParser(handler, HttpCompliance.CUSTOM0);
    //     parseAll(parser, buffer);

    //     Assert.assertContain(_bad, "Illegal character");
    //     Assert.assertTrue(_complianceViolation.contains(HttpComplianceSection.NO_WS_AFTER_FIELD_NAME));
    //     // Assert.assertThat(_complianceViolation, contains(HttpComplianceSection.NO_WS_AFTER_FIELD_NAME));
    // }

    
    // void testTrailingSpacesInHeaderNameInCustom0Mode() {
    //     ByteBuffer buffer = BufferUtils.toBuffer(
    //             "HTTP/1.1 204 No Content\r\n" ~
    //                     "Access-Control-Allow-Headers : Origin\r\n" ~
    //                     "Other\t : value\r\n" ~
    //                     "\r\n");

    //     HttpParser.ResponseHandler handler = new Handler();
    //     HttpParser parser = new HttpParser(handler, -1, HttpCompliance.CUSTOM0);
    //     parseAll(parser, buffer);

    //     Assert.assertTrue(_headerCompleted);
    //     Assert.assertTrue(_messageCompleted);

    //     Assert.assertEquals("HTTP/1.1", _methodOrVersion);
    //     Assert.assertEquals("204", _uriOrStatus);
    //     Assert.assertEquals("No Content", _versionOrReason);
    //     Assert.assertEquals(null, _content);

    //     Assert.assertEquals(1, _headers);
    //     writeln(Arrays.asList(_hdr));
    //     writeln(Arrays.asList(_val));
    //     Assert.assertEquals("Access-Control-Allow-Headers", _hdr[0]);
    //     Assert.assertEquals("Origin", _val[0]);
    //     Assert.assertEquals("Other", _hdr[1]);
    //     Assert.assertEquals("value", _val[1]);

    //     Assert.assertTrue(_complianceViolation.contains(HttpComplianceSection.NO_WS_AFTER_FIELD_NAME));
    //     // Assert.assertThat(_complianceViolation, contains(HttpComplianceSection.NO_WS_AFTER_FIELD_NAME, HttpComplianceSection.NO_WS_AFTER_FIELD_NAME));
    // }

    
    void testTrailingSpacesInHeaderNameNoCustom0() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "HTTP/1.1 204 No Content\r\n" ~
                        "Access-Control-Allow-Headers : Origin\r\n" ~
                        "Other: value\r\n" ~
                        "\r\n");

        HttpParser.ResponseHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parseAll(parser, buffer);

        Assert.assertEquals("HTTP/1.1", _methodOrVersion);
        Assert.assertEquals("204", _uriOrStatus);
        Assert.assertEquals("No Content", _versionOrReason);
        Assert.assertContain(_bad, "Illegal character 0x20");
    }

    
    void testNoColon7230() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET / HTTP/1.0\r\n" ~
                        "Host: localhost\r\n" ~
                        "Name\r\n" ~
                        "\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler, HttpCompliance.RFC7230_LEGACY);
        parseAll(parser, buffer);
        Assert.assertContain(_bad, "Illegal character");
        Assert.assertTrue(_complianceViolation.isEmpty());
    }


    
    void testHeaderParseDirect() {
        ByteBuffer b0 = BufferUtils.toBuffer(
                "GET / HTTP/1.0\r\n" ~
                        "Host: localhost\r\n" ~
                        "Header1: value1\r\n" ~
                        "Header2:   value 2a  \r\n" ~
                        "Header3: 3\r\n" ~
                        "Header4:value4\r\n" ~
                        "Server5: notServer\r\n" ~
                        "HostHeader: notHost\r\n" ~
                        "Connection: close\r\n" ~
                        "Accept-Encoding: gzip, deflated\r\n" ~
                        "Accept: unknown\r\n" ~
                        "\r\n");
        ByteBuffer buffer = BufferUtils.allocate(b0.capacity());
        int pos = BufferUtils.flipToFill(buffer);
        BufferUtils.put(b0, buffer);
        BufferUtils.flipToFlush(buffer, pos);

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parseAll(parser, buffer);

        Assert.assertEquals("GET", _methodOrVersion);
        Assert.assertEquals("/", _uriOrStatus);
        Assert.assertEquals("HTTP/1.0", _versionOrReason);
        Assert.assertEquals("Host", _hdr[0]);
        Assert.assertEquals("localhost", _val[0]);
        Assert.assertEquals("Header1", _hdr[1]);
        Assert.assertEquals("value1", _val[1]);
        Assert.assertEquals("Header2", _hdr[2]);
        Assert.assertEquals("value 2a", _val[2]);
        Assert.assertEquals("Header3", _hdr[3]);
        Assert.assertEquals("3", _val[3]);
        Assert.assertEquals("Header4", _hdr[4]);
        Assert.assertEquals("value4", _val[4]);
        Assert.assertEquals("Server5", _hdr[5]);
        Assert.assertEquals("notServer", _val[5]);
        Assert.assertEquals("HostHeader", _hdr[6]);
        Assert.assertEquals("notHost", _val[6]);
        Assert.assertEquals("Connection", _hdr[7]);
        Assert.assertEquals("close", _val[7]);
        Assert.assertEquals("Accept-Encoding", _hdr[8]);
        Assert.assertEquals("gzip, deflated", _val[8]);
        Assert.assertEquals("Accept", _hdr[9]);
        Assert.assertEquals("unknown", _val[9]);
        Assert.assertEquals(9, _headers);
    }

    
    void testHeaderParseCRLF() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET / HTTP/1.0\r\n" ~
                        "Host: localhost\r\n" ~
                        "Header1: value1\r\n" ~
                        "Header2:   value 2a  \r\n" ~
                        "Header3: 3\r\n" ~
                        "Header4:value4\r\n" ~
                        "Server5: notServer\r\n" ~
                        "HostHeader: notHost\r\n" ~
                        "Connection: close\r\n" ~
                        "Accept-Encoding: gzip, deflated\r\n" ~
                        "Accept: unknown\r\n" ~
                        "\r\n");
        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parseAll(parser, buffer);

        Assert.assertEquals("GET", _methodOrVersion);
        Assert.assertEquals("/", _uriOrStatus);
        Assert.assertEquals("HTTP/1.0", _versionOrReason);
        Assert.assertEquals("Host", _hdr[0]);
        Assert.assertEquals("localhost", _val[0]);
        Assert.assertEquals("Header1", _hdr[1]);
        Assert.assertEquals("value1", _val[1]);
        Assert.assertEquals("Header2", _hdr[2]);
        Assert.assertEquals("value 2a", _val[2]);
        Assert.assertEquals("Header3", _hdr[3]);
        Assert.assertEquals("3", _val[3]);
        Assert.assertEquals("Header4", _hdr[4]);
        Assert.assertEquals("value4", _val[4]);
        Assert.assertEquals("Server5", _hdr[5]);
        Assert.assertEquals("notServer", _val[5]);
        Assert.assertEquals("HostHeader", _hdr[6]);
        Assert.assertEquals("notHost", _val[6]);
        Assert.assertEquals("Connection", _hdr[7]);
        Assert.assertEquals("close", _val[7]);
        Assert.assertEquals("Accept-Encoding", _hdr[8]);
        Assert.assertEquals("gzip, deflated", _val[8]);
        Assert.assertEquals("Accept", _hdr[9]);
        Assert.assertEquals("unknown", _val[9]);
        Assert.assertEquals(9, _headers);
    }

    
    void testHeaderParseLF() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET / HTTP/1.0\n" ~
                        "Host: localhost\n" ~
                        "Header1: value1\n" ~
                        "Header2:   value 2a value 2b  \n" ~
                        "Header3: 3\n" ~
                        "Header4:value4\n" ~
                        "Server5: notServer\n" ~
                        "HostHeader: notHost\n" ~
                        "Connection: close\n" ~
                        "Accept-Encoding: gzip, deflated\n" ~
                        "Accept: unknown\n" ~
                        "\n");
        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parseAll(parser, buffer);

        Assert.assertEquals("GET", _methodOrVersion);
        Assert.assertEquals("/", _uriOrStatus);
        Assert.assertEquals("HTTP/1.0", _versionOrReason);
        Assert.assertEquals("Host", _hdr[0]);
        Assert.assertEquals("localhost", _val[0]);
        Assert.assertEquals("Header1", _hdr[1]);
        Assert.assertEquals("value1", _val[1]);
        Assert.assertEquals("Header2", _hdr[2]);
        Assert.assertEquals("value 2a value 2b", _val[2]);
        Assert.assertEquals("Header3", _hdr[3]);
        Assert.assertEquals("3", _val[3]);
        Assert.assertEquals("Header4", _hdr[4]);
        Assert.assertEquals("value4", _val[4]);
        Assert.assertEquals("Server5", _hdr[5]);
        Assert.assertEquals("notServer", _val[5]);
        Assert.assertEquals("HostHeader", _hdr[6]);
        Assert.assertEquals("notHost", _val[6]);
        Assert.assertEquals("Connection", _hdr[7]);
        Assert.assertEquals("close", _val[7]);
        Assert.assertEquals("Accept-Encoding", _hdr[8]);
        Assert.assertEquals("gzip, deflated", _val[8]);
        Assert.assertEquals("Accept", _hdr[9]);
        Assert.assertEquals("unknown", _val[9]);
        Assert.assertEquals(9, _headers);
    }

    
    void testQuoted() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET / HTTP/1.0\n" ~
                        "Name0: \"value0\"\t\n" ~
                        "Name1: \"value\t1\"\n" ~
                        "Name2: \"value\t2A\",\"value,2B\"\t\n" ~
                        "\n");
        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parseAll(parser, buffer);

        Assert.assertEquals("GET", _methodOrVersion);
        Assert.assertEquals("/", _uriOrStatus);
        Assert.assertEquals("HTTP/1.0", _versionOrReason);
        Assert.assertEquals("Name0", _hdr[0]);
        Assert.assertEquals("\"value0\"", _val[0]);
        Assert.assertEquals("Name1", _hdr[1]);
        Assert.assertEquals("\"value\t1\"", _val[1]);
        Assert.assertEquals("Name2", _hdr[2]);
        Assert.assertEquals("\"value\t2A\",\"value,2B\"", _val[2]);
        Assert.assertEquals(2, _headers);
    }

    
    void testEncodedHeader() {
        ByteBuffer buffer = BufferUtils.allocate(4096);
        BufferUtils.flipToFill(buffer);
        BufferUtils.put(BufferUtils.toBuffer("GET "), buffer);
        buffer.put("/foo/\u0690/");
        BufferUtils.put(BufferUtils.toBuffer(" HTTP/1.0\r\n"), buffer);
        BufferUtils.put(BufferUtils.toBuffer("Header1: "), buffer);
        buffer.put("\u00e6 \u00e6");
        BufferUtils.put(BufferUtils.toBuffer("  \r\nHeader2: "), buffer);
        buffer.put(cast(byte) -1);
        BufferUtils.put(BufferUtils.toBuffer("\r\n\r\n"), buffer);
        BufferUtils.flipToFlush(buffer, 0);

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parseAll(parser, buffer);

        Assert.assertEquals("GET", _methodOrVersion);
        Assert.assertEquals("/foo/\u0690/", _uriOrStatus);
        Assert.assertEquals("HTTP/1.0", _versionOrReason);
        Assert.assertEquals("Header1", _hdr[0]);
        Assert.assertEquals("\u00e6 \u00e6", _val[0]);
        Assert.assertEquals("Header2", _hdr[1]);
        Assert.assertEquals("" ~ to!string( cast(char)255), _val[1]);
        Assert.assertEquals(1, _headers);
        // FIXME: Needing refactor or cleanup -@zxp at 7/9/2018, 3:38:20 PM
        // 
        // Assert.assertEquals(null, _bad);
    }

    
    void testResponseBufferUpgradeFrom() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "HTTP/1.1 101 Upgrade\r\n" ~
                        "Connection: upgrade\r\n" ~
                        "Content-Length: 0\r\n" ~
                        "Sec-WebSocket-Accept: 4GnyoUP4Sc1JD+2pCbNYAhFYVVA\r\n" ~
                        "\r\n" ~
                        "FOOGRADE");

        HttpParser.ResponseHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);

        while (!parser.isState(State.END)) {
            parser.parseNext(buffer);
        }

        Assert.assertThat(BufferUtils.toString(buffer), ("FOOGRADE"));
    }

    
    void testBadMethodEncoding() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "G\u00e6T / HTTP/1.0\r\nHeader0: value0\r\n\n\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parseAll(parser, buffer);
        Assert.assertTrue(!_bad.empty);
    }

    
    void testBadVersionEncoding() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET / H\u00e6P/1.0\r\nHeader0: value0\r\n\n\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parseAll(parser, buffer);
        Assert.assertTrue(!_bad.empty);
    }

    
    void testBadHeaderEncoding() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET / HTTP/1.0\r\n"
                        ~ "H\u00e6der0: value0\r\n"
                        ~ "\n\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parseAll(parser, buffer);
        Assert.assertTrue(!_bad.empty);
    }

    
    void testHeaderTab() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET / HTTP/1.1\r\n" ~
                        "Host: localhost\r\n" ~
                        "Header: value\talternate\r\n" ~
                        "\n\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parseAll(parser, buffer);

        Assert.assertEquals("GET", _methodOrVersion);
        Assert.assertEquals("/", _uriOrStatus);
        Assert.assertEquals("HTTP/1.1", _versionOrReason);
        Assert.assertEquals("Host", _hdr[0]);
        Assert.assertEquals("localhost", _val[0]);
        Assert.assertEquals("Header", _hdr[1]);
        Assert.assertEquals("value\talternate", _val[1]);
    }

    
    void testCaseSensitiveMethod() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "gEt / http/1.0\r\n" ~
                        "Host: localhost\r\n" ~
                        "Connection: close\r\n" ~
                        "\r\n");
        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler, -1, HttpCompliance.RFC7230_LEGACY);
        parseAll(parser, buffer);
        // FIXME: Needing refactor or cleanup -@Administrator at 2018-7-10 10:40:02
        // 
        // Assert.assertNull(_bad);
        // Assert.assertEquals("GET", _methodOrVersion);
        // Assert.assertTrue(_complianceViolation.contains(HttpComplianceSection.METHOD_CASE_SENSITIVE));
    }

    
    void testCaseSensitiveMethodLegacy() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "gEt / http/1.0\r\n" ~
                        "Host: localhost\r\n" ~
                        "Connection: close\r\n" ~
                        "\r\n");
        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler, -1, HttpCompliance.LEGACY);
        parseAll(parser, buffer);
        // Assert.assertNull(_bad);
        Assert.assertEquals("gEt", _methodOrVersion);
        Assert.assertTrue(_complianceViolation.isEmpty());
    }

    
    void testCaseInsensitiveHeader() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET / http/1.0\r\n" ~
                        "HOST: localhost\r\n" ~
                        "cOnNeCtIoN: ClOsE\r\n" ~
                        "\r\n");
        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler, -1, HttpCompliance.RFC7230_LEGACY);
        parseAll(parser, buffer);
        // Assert.assertNull(_bad);
        Assert.assertEquals("GET", _methodOrVersion);
        Assert.assertEquals("/", _uriOrStatus);
        Assert.assertEquals("HTTP/1.0", _versionOrReason);
        // Assert.assertEquals("Host", _hdr[0]);
        Assert.assertEquals("localhost", _val[0]);
        // Assert.assertEquals("Connection", _hdr[1]);
        // Assert.assertEquals("close", _val[1]);
        Assert.assertEquals(1, _headers);
        Assert.assertTrue(_complianceViolation.isEmpty());
    }

    
    void testCaseInSensitiveHeaderLegacy() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET / http/1.0\r\n" ~
                        "HOST: localhost\r\n" ~
                        "cOnNeCtIoN: ClOsE\r\n" ~
                        "\r\n");
        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler, -1, HttpCompliance.LEGACY);
        parseAll(parser, buffer);
        // Assert.assertNull(_bad);
        Assert.assertEquals("GET", _methodOrVersion);
        Assert.assertEquals("/", _uriOrStatus);
        Assert.assertEquals("HTTP/1.0", _versionOrReason);
        Assert.assertEquals("HOST", _hdr[0]);
        Assert.assertEquals("localhost", _val[0]);
        Assert.assertEquals("cOnNeCtIoN", _hdr[1]);
        Assert.assertEquals("ClOsE", _val[1]);
        Assert.assertEquals(1, _headers);
        // Assert.assertTrue(_complianceViolation.contains(HttpComplianceSection.FIELD_NAME_CASE_INSENSITIVE));
    }

    
    void testSplitHeaderParse() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "XXXXSPLIT / HTTP/1.0\r\n" ~
                        "Host: localhost\r\n" ~
                        "Header1: value1\r\n" ~
                        "Header2:   value 2a  \r\n" ~
                        "Header3: 3\r\n" ~
                        "Header4:value4\r\n" ~
                        "Server5: notServer\r\n" ~
                        "\r\nZZZZ");
        buffer.position(2);
        buffer.limit(buffer.capacity() - 2);
        buffer = buffer.slice();

        for (int i = 0; i < buffer.capacity() - 4; i++) {
            HttpParser.RequestHandler handler = new Handler();
            HttpParser parser = new HttpParser(handler);

            buffer.position(2);
            buffer.limit(2 + i);

            if (!parser.parseNext(buffer)) {
                // consumed all
                Assert.assertEquals(0, buffer.remaining());

                // parse the rest
                buffer.limit(buffer.capacity() - 2);
                parser.parseNext(buffer);
            }

            Assert.assertEquals("SPLIT", _methodOrVersion);
            Assert.assertEquals("/", _uriOrStatus);
            Assert.assertEquals("HTTP/1.0", _versionOrReason);
            Assert.assertEquals("Host", _hdr[0]);
            Assert.assertEquals("localhost", _val[0]);
            Assert.assertEquals("Header1", _hdr[1]);
            Assert.assertEquals("value1", _val[1]);
            Assert.assertEquals("Header2", _hdr[2]);
            Assert.assertEquals("value 2a", _val[2]);
            Assert.assertEquals("Header3", _hdr[3]);
            Assert.assertEquals("3", _val[3]);
            Assert.assertEquals("Header4", _hdr[4]);
            Assert.assertEquals("value4", _val[4]);
            Assert.assertEquals("Server5", _hdr[5]);
            Assert.assertEquals("notServer", _val[5]);
            Assert.assertEquals(5, _headers);
        }
    }

    
    void testChunkParse() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET /chunk HTTP/1.0\r\n"
                        ~ "Header1: value1\r\n"
                        ~ "Transfer-Encoding: chunked\r\n"
                        ~ "\r\n"
                        ~ "a;\r\n"
                        ~ "0123456789\r\n"
                        ~ "1a\r\n"
                        ~ "ABCDEFGHIJKLMNOPQRSTUVWXYZ\r\n"
                        ~ "0\r\n"
                        ~ "\r\n");
        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parseAll(parser, buffer);

        Assert.assertEquals("GET", _methodOrVersion);
        Assert.assertEquals("/chunk", _uriOrStatus);
        Assert.assertEquals("HTTP/1.0", _versionOrReason);
        Assert.assertEquals(1, _headers);
        Assert.assertEquals("Header1", _hdr[0]);
        Assert.assertEquals("value1", _val[0]);
        // FIXME: Needing refactor or cleanup -@Administrator at 2018-7-9 17:40:26
        // 
        // Assert.assertEquals("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ", _content);

        Assert.assertTrue(_headerCompleted);
        Assert.assertTrue(_messageCompleted);
    }


    
    void testBadChunkParse() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET /chunk HTTP/1.0\r\n"
                        ~ "Header1: value1\r\n"
                        ~ "Transfer-Encoding: chunked, identity\r\n"
                        ~ "\r\n"
                        ~ "a;\r\n"
                        ~ "0123456789\r\n"
                        ~ "1a\r\n"
                        ~ "ABCDEFGHIJKLMNOPQRSTUVWXYZ\r\n"
                        ~ "0\r\n"
                        ~ "\r\n");
        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parseAll(parser, buffer);

        Assert.assertEquals("GET", _methodOrVersion);
        Assert.assertEquals("/chunk", _uriOrStatus);
        Assert.assertEquals("HTTP/1.0", _versionOrReason);
        // Assert.assertContain(_bad, "Bad chunking");
    }

    
    void testChunkParseTrailer() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET /chunk HTTP/1.0\r\n"
                        ~ "Header1: value1\r\n"
                        ~ "Transfer-Encoding: chunked\r\n"
                        ~ "\r\n"
                        ~ "a;\r\n"
                        ~ "0123456789\r\n"
                        ~ "1a\r\n"
                        ~ "ABCDEFGHIJKLMNOPQRSTUVWXYZ\r\n"
                        ~ "0\r\n"
                        ~ "Trailer: value\r\n"
                        ~ "\r\n");
        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parseAll(parser, buffer);

        Assert.assertEquals("GET", _methodOrVersion);
        Assert.assertEquals("/chunk", _uriOrStatus);
        Assert.assertEquals("HTTP/1.0", _versionOrReason);
        Assert.assertEquals(1, _headers);
        Assert.assertEquals("Header1", _hdr[0]);
        Assert.assertEquals("value1", _val[0]);
        // FIXME: Needing refactor or cleanup -@Administrator at 2018-7-9 17:42:08
        // 
        // Assert.assertEquals("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ", _content);
        // Assert.assertEquals(1, _trailers.size());
        // HttpField trailer1 = _trailers.get(0);
        // Assert.assertEquals("Trailer", trailer1.getName());
        // Assert.assertEquals("value", trailer1.getValue());

        Assert.assertTrue(_headerCompleted);
        Assert.assertTrue(_messageCompleted);
    }

    
    void testChunkParseTrailers() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET /chunk HTTP/1.0\r\n"
                        ~ "Transfer-Encoding: chunked\r\n"
                        ~ "\r\n"
                        ~ "a;\r\n"
                        ~ "0123456789\r\n"
                        ~ "1a\r\n"
                        ~ "ABCDEFGHIJKLMNOPQRSTUVWXYZ\r\n"
                        ~ "0\r\n"
                        ~ "Trailer: value\r\n"
                        ~ "Foo: bar\r\n"
                        ~ "\r\n");
        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parseAll(parser, buffer);

        Assert.assertEquals("GET", _methodOrVersion);
        Assert.assertEquals("/chunk", _uriOrStatus);
        Assert.assertEquals("HTTP/1.0", _versionOrReason);
        Assert.assertEquals(0, _headers);
        Assert.assertEquals("Transfer-Encoding", _hdr[0]);
        Assert.assertEquals("chunked", _val[0]);
        // FIXME: Needing refactor or cleanup -@Administrator at 2018-7-9 17:43:39
        // 
        // Assert.assertEquals("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ", _content);
        // Assert.assertEquals(2, _trailers.size());
        // HttpField trailer1 = _trailers.get(0);
        // Assert.assertEquals("Trailer", trailer1.getName());
        // Assert.assertEquals("value", trailer1.getValue());
        // HttpField trailer2 = _trailers.get(1);
        // Assert.assertEquals("Foo", trailer2.getName());
        // Assert.assertEquals("bar", trailer2.getValue());

        Assert.assertTrue(_headerCompleted);
        Assert.assertTrue(_messageCompleted);
    }

    
    void testChunkParseBadTrailer() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET /chunk HTTP/1.0\r\n"
                        ~ "Header1: value1\r\n"
                        ~ "Transfer-Encoding: chunked\r\n"
                        ~ "\r\n"
                        ~ "a;\r\n"
                        ~ "0123456789\r\n"
                        ~ "1a\r\n"
                        ~ "ABCDEFGHIJKLMNOPQRSTUVWXYZ\r\n"
                        ~ "0\r\n"
                        ~ "Trailer: value");
        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parseAll(parser, buffer);
        parser.atEOF();
        parser.parseNext(BufferUtils.EMPTY_BUFFER);

        Assert.assertEquals("GET", _methodOrVersion);
        Assert.assertEquals("/chunk", _uriOrStatus);
        Assert.assertEquals("HTTP/1.0", _versionOrReason);
        Assert.assertEquals(1, _headers);
        Assert.assertEquals("Header1", _hdr[0]);
        Assert.assertEquals("value1", _val[0]);
        // Assert.assertEquals("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ", _content);

        Assert.assertTrue(_headerCompleted);
        // Assert.assertTrue(_early);
    }


    
    void testChunkParseNoTrailer() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET /chunk HTTP/1.0\r\n"
                        ~ "Header1: value1\r\n"
                        ~ "Transfer-Encoding: chunked\r\n"
                        ~ "\r\n"
                        ~ "a;\r\n"
                        ~ "0123456789\r\n"
                        ~ "1a\r\n"
                        ~ "ABCDEFGHIJKLMNOPQRSTUVWXYZ\r\n"
                        ~ "0\r\n");
        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parseAll(parser, buffer);
        parser.atEOF();
        parser.parseNext(BufferUtils.EMPTY_BUFFER);

        Assert.assertEquals("GET", _methodOrVersion);
        Assert.assertEquals("/chunk", _uriOrStatus);
        Assert.assertEquals("HTTP/1.0", _versionOrReason);
        Assert.assertEquals(1, _headers);
        Assert.assertEquals("Header1", _hdr[0]);
        Assert.assertEquals("value1", _val[0]);
        // Assert.assertEquals("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ", _content);

        Assert.assertTrue(_headerCompleted);
        Assert.assertTrue(_messageCompleted);
    }

    
    void testStartEOF() {
        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parser.atEOF();
        parser.parseNext(BufferUtils.EMPTY_BUFFER);

        Assert.assertTrue(_early);
        // Assert.assertEquals(null, _bad);
    }

    
    void testEarlyEOF() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET /uri HTTP/1.0\r\n"
                        ~ "Content-Length: 20\r\n"
                        ~ "\r\n"
                        ~ "0123456789");
        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parser.atEOF();
        parseAll(parser, buffer);

        Assert.assertEquals("GET", _methodOrVersion);
        Assert.assertEquals("/uri", _uriOrStatus);
        Assert.assertEquals("HTTP/1.0", _versionOrReason);
        // Assert.assertEquals("0123456789", _content);

        // Assert.assertTrue(_early);
    }

    
    // void testChunkEarlyEOF() {
    //     ByteBuffer buffer = BufferUtils.toBuffer(
    //             "GET /chunk HTTP/1.0\r\n"
    //                     ~ "Header1: value1\r\n"
    //                     ~ "Transfer-Encoding: chunked\r\n"
    //                     ~ "\r\n"
    //                     ~ "a;\r\n"
    //                     ~ "0123456789\r\n");
    //     HttpParser.RequestHandler handler = new Handler();
    //     HttpParser parser = new HttpParser(handler);
    //     parser.atEOF();
    //     parseAll(parser, buffer);

    //     Assert.assertEquals("GET", _methodOrVersion);
    //     Assert.assertEquals("/chunk", _uriOrStatus);
    //     Assert.assertEquals("HTTP/1.0", _versionOrReason);
    //     Assert.assertEquals(1, _headers);
    //     Assert.assertEquals("Header1", _hdr[0]);
    //     Assert.assertEquals("value1", _val[0]);
    //     Assert.assertEquals("0123456789", _content);

    //     Assert.assertTrue(_early);
    // }

    
    // void testMultiParse() {
    //     ByteBuffer buffer = BufferUtils.toBuffer(
    //             "GET /mp HTTP/1.0\r\n"
    //                     ~ "Connection: Keep-Alive\r\n"
    //                     ~ "Header1: value1\r\n"
    //                     ~ "Transfer-Encoding: chunked\r\n"
    //                     ~ "\r\n"
    //                     ~ "a;\r\n"
    //                     ~ "0123456789\r\n"
    //                     ~ "1a\r\n"
    //                     ~ "ABCDEFGHIJKLMNOPQRSTUVWXYZ\r\n"
    //                     ~ "0\r\n"

    //                     ~ "\r\n"

    //                     ~ "POST /foo HTTP/1.0\r\n"
    //                     ~ "Connection: Keep-Alive\r\n"
    //                     ~ "Header2: value2\r\n"
    //                     ~ "Content-Length: 0\r\n"
    //                     ~ "\r\n"

    //                     ~ "PUT /doodle HTTP/1.0\r\n"
    //                     ~ "Connection: close\r\n"
    //                     ~ "Header3: value3\r\n"
    //                     ~ "Content-Length: 10\r\n"
    //                     ~ "\r\n"
    //                     ~ "0123456789\r\n");

    //     HttpParser.RequestHandler handler = new Handler();
    //     HttpParser parser = new HttpParser(handler);
    //     parser.parseNext(buffer);
    //     Assert.assertEquals("GET", _methodOrVersion);
    //     Assert.assertEquals("/mp", _uriOrStatus);
    //     Assert.assertEquals("HTTP/1.0", _versionOrReason);
    //     Assert.assertEquals(2, _headers);
    //     Assert.assertEquals("Header1", _hdr[1]);
    //     Assert.assertEquals("value1", _val[1]);
    //     // Assert.assertEquals("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ", _content);

    //     parser.reset();
    //     init();
    //     parser.parseNext(buffer);
    //     Assert.assertEquals("POST", _methodOrVersion);
    //     Assert.assertEquals("/foo", _uriOrStatus);
    //     Assert.assertEquals("HTTP/1.0", _versionOrReason);
    //     Assert.assertEquals(2, _headers);
    //     Assert.assertEquals("Header2", _hdr[1]);
    //     Assert.assertEquals("value2", _val[1]);
    //     Assert.assertEquals(null, _content);

    //     parser.reset();
    //     init();
    //     parser.parseNext(buffer);
    //     parser.atEOF();
    //     Assert.assertEquals("PUT", _methodOrVersion);
    //     Assert.assertEquals("/doodle", _uriOrStatus);
    //     Assert.assertEquals("HTTP/1.0", _versionOrReason);
    //     Assert.assertEquals(2, _headers);
    //     Assert.assertEquals("Header3", _hdr[1]);
    //     Assert.assertEquals("value3", _val[1]);
    //     Assert.assertEquals("0123456789", _content);
    // }

    
    // void testMultiParseEarlyEOF() {
    //     ByteBuffer buffer0 = BufferUtils.toBuffer(
    //             "GET /mp HTTP/1.0\r\n"
    //                     ~ "Connection: Keep-Alive\r\n");

    //     ByteBuffer buffer1 = BufferUtils.toBuffer("Header1: value1\r\n"
    //             ~ "Transfer-Encoding: chunked\r\n"
    //             ~ "\r\n"
    //             ~ "a;\r\n"
    //             ~ "0123456789\r\n"
    //             ~ "1a\r\n"
    //             ~ "ABCDEFGHIJKLMNOPQRSTUVWXYZ\r\n"
    //             ~ "0\r\n"

    //             ~ "\r\n"

    //             ~ "POST /foo HTTP/1.0\r\n"
    //             ~ "Connection: Keep-Alive\r\n"
    //             ~ "Header2: value2\r\n"
    //             ~ "Content-Length: 0\r\n"
    //             ~ "\r\n"

    //             ~ "PUT /doodle HTTP/1.0\r\n"
    //             ~ "Connection: close\r\n"
    //             ~ "Header3: value3\r\n"
    //             ~ "Content-Length: 10\r\n"
    //             ~ "\r\n"
    //             ~ "0123456789\r\n");

    //     HttpParser.RequestHandler handler = new Handler();
    //     HttpParser parser = new HttpParser(handler);
    //     parser.parseNext(buffer0);
    //     parser.atEOF();
    //     parser.parseNext(buffer1);
    //     Assert.assertEquals("GET", _methodOrVersion);
    //     Assert.assertEquals("/mp", _uriOrStatus);
    //     Assert.assertEquals("HTTP/1.0", _versionOrReason);
    //     Assert.assertEquals(2, _headers);
    //     Assert.assertEquals("Header1", _hdr[1]);
    //     Assert.assertEquals("value1", _val[1]);
    //     Assert.assertEquals("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ", _content);

    //     parser.reset();
    //     init();
    //     parser.parseNext(buffer1);
    //     Assert.assertEquals("POST", _methodOrVersion);
    //     Assert.assertEquals("/foo", _uriOrStatus);
    //     Assert.assertEquals("HTTP/1.0", _versionOrReason);
    //     Assert.assertEquals(2, _headers);
    //     Assert.assertEquals("Header2", _hdr[1]);
    //     Assert.assertEquals("value2", _val[1]);
    //     Assert.assertEquals(null, _content);

    //     parser.reset();
    //     init();
    //     parser.parseNext(buffer1);
    //     Assert.assertEquals("PUT", _methodOrVersion);
    //     Assert.assertEquals("/doodle", _uriOrStatus);
    //     Assert.assertEquals("HTTP/1.0", _versionOrReason);
    //     Assert.assertEquals(2, _headers);
    //     Assert.assertEquals("Header3", _hdr[1]);
    //     Assert.assertEquals("value3", _val[1]);
    //     Assert.assertEquals("0123456789", _content);
    // }

    
    void testResponseParse0() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "HTTP/1.1 200 Correct\r\n"
                        ~ "Content-Length: 10\r\n"
                        ~ "Content-Type: text/plain\r\n"
                        ~ "\r\n"
                        ~ "0123456789\r\n");

        HttpParser.ResponseHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parser.parseNext(buffer);
        Assert.assertEquals("HTTP/1.1", _methodOrVersion);
        Assert.assertEquals("200", _uriOrStatus);
        Assert.assertEquals("Correct", _versionOrReason);
        Assert.assertEquals(10, _content.length);
        Assert.assertTrue(_headerCompleted);
        Assert.assertTrue(_messageCompleted);
    }

    
    void testResponseParse1() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "HTTP/1.1 304 Not-Modified\r\n"
                        ~ "Connection: close\r\n"
                        ~ "\r\n");

        HttpParser.ResponseHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parser.parseNext(buffer);
        Assert.assertEquals("HTTP/1.1", _methodOrVersion);
        Assert.assertEquals("304", _uriOrStatus);
        Assert.assertEquals("Not-Modified", _versionOrReason);
        Assert.assertTrue(_headerCompleted);
        Assert.assertTrue(_messageCompleted);
    }

    
    void testResponseParse2() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "HTTP/1.1 204 No-Content\r\n"
                        ~ "Header: value\r\n"
                        ~ "\r\n"

                        ~ "HTTP/1.1 200 Correct\r\n"
                        ~ "Content-Length: 10\r\n"
                        ~ "Content-Type: text/plain\r\n"
                        ~ "\r\n"
                        ~ "0123456789\r\n");

        HttpParser.ResponseHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parser.parseNext(buffer);
        Assert.assertEquals("HTTP/1.1", _methodOrVersion);
        Assert.assertEquals("204", _uriOrStatus);
        Assert.assertEquals("No-Content", _versionOrReason);
        Assert.assertTrue(_headerCompleted);
        Assert.assertTrue(_messageCompleted);

        parser.reset();
        init();

        parser.parseNext(buffer);
        parser.atEOF();
        Assert.assertEquals("HTTP/1.1", _methodOrVersion);
        Assert.assertEquals("200", _uriOrStatus);
        Assert.assertEquals("Correct", _versionOrReason);
        Assert.assertEquals(_content.length, 10);
        Assert.assertTrue(_headerCompleted);
        Assert.assertTrue(_messageCompleted);
    }

    
    void testResponseParse3() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "HTTP/1.1 200\r\n"
                        ~ "Content-Length: 10\r\n"
                        ~ "Content-Type: text/plain\r\n"
                        ~ "\r\n"
                        ~ "0123456789\r\n");

        HttpParser.ResponseHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parser.parseNext(buffer);
        Assert.assertEquals("HTTP/1.1", _methodOrVersion);
        Assert.assertEquals("200", _uriOrStatus);
        Assert.assertEquals(null, _versionOrReason);
        Assert.assertEquals(_content.length, 10);
        Assert.assertTrue(_headerCompleted);
        Assert.assertTrue(_messageCompleted);
    }

    
    void testResponseParse4() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "HTTP/1.1 200 \r\n"
                        ~ "Content-Length: 10\r\n"
                        ~ "Content-Type: text/plain\r\n"
                        ~ "\r\n"
                        ~ "0123456789\r\n");

        HttpParser.ResponseHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parser.parseNext(buffer);
        Assert.assertEquals("HTTP/1.1", _methodOrVersion);
        Assert.assertEquals("200", _uriOrStatus);
        Assert.assertEquals(null, _versionOrReason);
        Assert.assertEquals(_content.length, 10);
        Assert.assertTrue(_headerCompleted);
        Assert.assertTrue(_messageCompleted);
    }

    
    void testResponseEOFContent() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "HTTP/1.1 200 \r\n"
                        ~ "Content-Type: text/plain\r\n"
                        ~ "\r\n"
                        ~ "0123456789\r\n");

        HttpParser.ResponseHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parser.atEOF();
        parser.parseNext(buffer);

        Assert.assertEquals("HTTP/1.1", _methodOrVersion);
        Assert.assertEquals("200", _uriOrStatus);
        Assert.assertEquals(null, _versionOrReason);
        Assert.assertEquals(12, _content.length);
        Assert.assertEquals("0123456789\r\n", _content);
        Assert.assertTrue(_headerCompleted);
        Assert.assertTrue(_messageCompleted);
    }

    
    void testResponse304WithContentLength() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "HTTP/1.1 304 found\r\n"
                        ~ "Content-Length: 10\r\n"
                        ~ "\r\n");

        HttpParser.ResponseHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parser.parseNext(buffer);
        Assert.assertEquals("HTTP/1.1", _methodOrVersion);
        Assert.assertEquals("304", _uriOrStatus);
        Assert.assertEquals("found", _versionOrReason);
        Assert.assertEquals(null, _content);
        Assert.assertTrue(_headerCompleted);
        Assert.assertTrue(_messageCompleted);
    }

    
    void testResponse101WithTransferEncoding() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "HTTP/1.1 101 switching protocols\r\n"
                        ~ "Transfer-Encoding: chunked\r\n"
                        ~ "\r\n");

        HttpParser.ResponseHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parser.parseNext(buffer);
        Assert.assertEquals("HTTP/1.1", _methodOrVersion);
        Assert.assertEquals("101", _uriOrStatus);
        Assert.assertEquals("switching protocols", _versionOrReason);
        Assert.assertEquals(null, _content);
        Assert.assertTrue(_headerCompleted);
        Assert.assertTrue(_messageCompleted);
    }

    
    void testResponseReasonIso8859_1() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "HTTP/1.1 302 déplacé temporairement\r\n"
                        ~ "Content-Length: 0\r\n"
                        ~ "\r\n");

        HttpParser.ResponseHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parser.parseNext(buffer);
        Assert.assertEquals("HTTP/1.1", _methodOrVersion);
        Assert.assertEquals("302", _uriOrStatus);
        Assert.assertEquals("déplacé temporairement", _versionOrReason);
    }

    
    void testSeekEOF() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "HTTP/1.1 200 OK\r\n"
                        ~ "Content-Length: 0\r\n"
                        ~ "Connection: close\r\n"
                        ~ "\r\n"
                        ~ "\r\n" // extra CRLF ignored
                        ~ "HTTP/1.1 400 OK\r\n");  // extra data causes close ??

        HttpParser.ResponseHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);

        parser.parseNext(buffer);
        Assert.assertEquals("HTTP/1.1", _methodOrVersion);
        Assert.assertEquals("200", _uriOrStatus);
        Assert.assertEquals("OK", _versionOrReason);
        Assert.assertEquals(null, _content);
        Assert.assertTrue(_headerCompleted);
        Assert.assertTrue(_messageCompleted);

        parser.close();
        parser.reset();
        parser.parseNext(buffer);
        Assert.assertFalse(buffer.hasRemaining());
        Assert.assertEquals(HttpParser.State.CLOSE, parser.getState());
        parser.atEOF();
        parser.parseNext(BufferUtils.EMPTY_BUFFER);
        Assert.assertEquals(HttpParser.State.CLOSED, parser.getState());
    }

    
    void testNoURI() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET\r\n"
                        ~ "Content-Length: 0\r\n"
                        ~ "Connection: close\r\n"
                        ~ "\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);

        parser.parseNext(buffer);
        // FIXME: Needing refactor or cleanup -@Administrator at 2018-7-10 10:46:59
        // 
        // Assert.assertEquals(null, _methodOrVersion);
        Assert.assertEquals("No URI", _bad);
        Assert.assertFalse(buffer.hasRemaining());
        Assert.assertEquals(HttpParser.State.CLOSE, parser.getState());
        parser.atEOF();
        parser.parseNext(BufferUtils.EMPTY_BUFFER);
        Assert.assertEquals(HttpParser.State.CLOSED, parser.getState());
    }

    
    void testNoURI2() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET \r\n"
                        ~ "Content-Length: 0\r\n"
                        ~ "Connection: close\r\n"
                        ~ "\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);

        parser.parseNext(buffer);
        // Assert.assertEquals(null, _methodOrVersion);
        Assert.assertEquals("No URI", _bad);
        Assert.assertFalse(buffer.hasRemaining());
        Assert.assertEquals(HttpParser.State.CLOSE, parser.getState());
        parser.atEOF();
        parser.parseNext(BufferUtils.EMPTY_BUFFER);
        Assert.assertEquals(HttpParser.State.CLOSED, parser.getState());
    }

    
    void testUnknownReponseVersion() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "HPPT/7.7 200 OK\r\n"
                        ~ "Content-Length: 0\r\n"
                        ~ "Connection: close\r\n"
                        ~ "\r\n");

        HttpParser.ResponseHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);

        parser.parseNext(buffer);
        // Assert.assertEquals(null, _methodOrVersion);
        Assert.assertEquals("Unknown Version", _bad);
        Assert.assertFalse(buffer.hasRemaining());
        Assert.assertEquals(HttpParser.State.CLOSE, parser.getState());
        parser.atEOF();
        parser.parseNext(BufferUtils.EMPTY_BUFFER);
        Assert.assertEquals(HttpParser.State.CLOSED, parser.getState());

    }

    
    void testNoStatus() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "HTTP/1.1\r\n"
                        ~ "Content-Length: 0\r\n"
                        ~ "Connection: close\r\n"
                        ~ "\r\n");

        HttpParser.ResponseHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);

        parser.parseNext(buffer);
        // Assert.assertEquals(null, _methodOrVersion);
        Assert.assertEquals("No Status", _bad);
        Assert.assertFalse(buffer.hasRemaining());
        Assert.assertEquals(HttpParser.State.CLOSE, parser.getState());
        parser.atEOF();
        parser.parseNext(BufferUtils.EMPTY_BUFFER);
        Assert.assertEquals(HttpParser.State.CLOSED, parser.getState());
    }

    
    void testNoStatus2() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "HTTP/1.1 \r\n"
                        ~ "Content-Length: 0\r\n"
                        ~ "Connection: close\r\n"
                        ~ "\r\n");

        HttpParser.ResponseHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);

        parser.parseNext(buffer);
        // Assert.assertEquals(null, _methodOrVersion);
        Assert.assertEquals("No Status", _bad);
        Assert.assertFalse(buffer.hasRemaining());
        Assert.assertEquals(HttpParser.State.CLOSE, parser.getState());
        parser.atEOF();
        parser.parseNext(BufferUtils.EMPTY_BUFFER);
        Assert.assertEquals(HttpParser.State.CLOSED, parser.getState());
    }

    
    void testBadRequestVersion() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET / HPPT/7.7\r\n"
                        ~ "Content-Length: 0\r\n"
                        ~ "Connection: close\r\n"
                        ~ "\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);

        parser.parseNext(buffer);
        // Assert.assertEquals(null, _methodOrVersion);
        Assert.assertEquals("Unknown Version", _bad);
        Assert.assertFalse(buffer.hasRemaining());
        Assert.assertEquals(HttpParser.State.CLOSE, parser.getState());
        parser.atEOF();
        parser.parseNext(BufferUtils.EMPTY_BUFFER);
        Assert.assertEquals(HttpParser.State.CLOSED, parser.getState());

        buffer = BufferUtils.toBuffer(
                "GET / HTTP/1.01\r\n"
                        ~ "Content-Length: 0\r\n"
                        ~ "Connection: close\r\n"
                        ~ "\r\n");

        handler = new Handler();
        parser = new HttpParser(handler);

        parser.parseNext(buffer);
        // Assert.assertEquals(null, _methodOrVersion);
        Assert.assertEquals("Unknown Version", _bad);
        Assert.assertFalse(buffer.hasRemaining());
        Assert.assertEquals(HttpParser.State.CLOSE, parser.getState());
        parser.atEOF();
        parser.parseNext(BufferUtils.EMPTY_BUFFER);
        Assert.assertEquals(HttpParser.State.CLOSED, parser.getState());
    }

    
    void testBadCR() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET / HTTP/1.0\r\n"
                        ~ "Content-Length: 0\r"
                        ~ "Connection: close\r"
                        ~ "\r");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);

        parser.parseNext(buffer);
        Assert.assertEquals("Bad EOL", _bad);
        Assert.assertFalse(buffer.hasRemaining());
        Assert.assertEquals(HttpParser.State.CLOSE, parser.getState());
        parser.atEOF();
        parser.parseNext(BufferUtils.EMPTY_BUFFER);
        Assert.assertEquals(HttpParser.State.CLOSED, parser.getState());

        buffer = BufferUtils.toBuffer(
                "GET / HTTP/1.0\r"
                        ~ "Content-Length: 0\r"
                        ~ "Connection: close\r"
                        ~ "\r");

        handler = new Handler();
        parser = new HttpParser(handler);

        parser.parseNext(buffer);
        Assert.assertEquals("Bad EOL", _bad);
        Assert.assertFalse(buffer.hasRemaining());
        Assert.assertEquals(HttpParser.State.CLOSE, parser.getState());
        parser.atEOF();
        parser.parseNext(BufferUtils.EMPTY_BUFFER);
        Assert.assertEquals(HttpParser.State.CLOSED, parser.getState());
    }

    
    void testBadContentLength0() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET / HTTP/1.0\r\n"
                        ~ "Content-Length: abc\r\n"
                        ~ "Connection: close\r\n"
                        ~ "\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);

        parser.parseNext(buffer);
        Assert.assertEquals("GET", _methodOrVersion);
        Assert.assertEquals("Invalid Content-Length Value", _bad);
        Assert.assertFalse(buffer.hasRemaining());
        Assert.assertEquals(HttpParser.State.CLOSE, parser.getState());
        parser.atEOF();
        parser.parseNext(BufferUtils.EMPTY_BUFFER);
        Assert.assertEquals(HttpParser.State.CLOSED, parser.getState());
    }

    
    void testBadContentLength1() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET / HTTP/1.0\r\n"
                        ~ "Content-Length: 9999999999999999999999999999999999999999999999\r\n"
                        ~ "Connection: close\r\n"
                        ~ "\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);

        parser.parseNext(buffer);
        Assert.assertEquals("GET", _methodOrVersion);
        Assert.assertEquals("Invalid Content-Length Value", _bad);
        Assert.assertFalse(buffer.hasRemaining());
        Assert.assertEquals(HttpParser.State.CLOSE, parser.getState());
        parser.atEOF();
        parser.parseNext(BufferUtils.EMPTY_BUFFER);
        Assert.assertEquals(HttpParser.State.CLOSED, parser.getState());
    }

    
    void testBadContentLength2() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET / HTTP/1.0\r\n"
                        ~ "Content-Length: 1.5\r\n"
                        ~ "Connection: close\r\n"
                        ~ "\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);

        parser.parseNext(buffer);
        Assert.assertEquals("GET", _methodOrVersion);
        Assert.assertEquals("Invalid Content-Length Value", _bad);
        Assert.assertFalse(buffer.hasRemaining());
        Assert.assertEquals(HttpParser.State.CLOSE, parser.getState());
        parser.atEOF();
        parser.parseNext(BufferUtils.EMPTY_BUFFER);
        Assert.assertEquals(HttpParser.State.CLOSED, parser.getState());
    }

    
    void testDuplicateContentLengthWithLargerThenCorrectValue() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "POST / HTTP/1.1\r\n"
                        ~ "Content-Length: 2\r\n"
                        ~ "Content-Length: 1\r\n"
                        ~ "Connection: close\r\n"
                        ~ "\r\n"
                        ~ "X");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);

        parser.parseNext(buffer);
        Assert.assertEquals("POST", _methodOrVersion);
        Assert.assertEquals("Duplicate Content-Length", _bad);
        Assert.assertFalse(buffer.hasRemaining());
        Assert.assertEquals(HttpParser.State.CLOSE, parser.getState());
        parser.atEOF();
        parser.parseNext(BufferUtils.EMPTY_BUFFER);
        Assert.assertEquals(HttpParser.State.CLOSED, parser.getState());
    }

    
    void testDuplicateContentLengthWithCorrectThenLargerValue() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "POST / HTTP/1.1\r\n"
                        ~ "Content-Length: 1\r\n"
                        ~ "Content-Length: 2\r\n"
                        ~ "Connection: close\r\n"
                        ~ "\r\n"
                        ~ "X");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);

        parser.parseNext(buffer);
        Assert.assertEquals("POST", _methodOrVersion);
        Assert.assertEquals("Duplicate Content-Length", _bad);
        Assert.assertFalse(buffer.hasRemaining());
        Assert.assertEquals(HttpParser.State.CLOSE, parser.getState());
        parser.atEOF();
        parser.parseNext(BufferUtils.EMPTY_BUFFER);
        Assert.assertEquals(HttpParser.State.CLOSED, parser.getState());
    }

    
    void testTransferEncodingChunkedThenContentLength() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "POST /chunk HTTP/1.1\r\n"
                        ~ "Host: localhost\r\n"
                        ~ "Transfer-Encoding: chunked\r\n"
                        ~ "Content-Length: 1\r\n"
                        ~ "\r\n"
                        ~ "1\r\n"
                        ~ "X\r\n"
                        ~ "0\r\n"
                        ~ "\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parseAll(parser, buffer);

        Assert.assertEquals("POST", _methodOrVersion);
        Assert.assertEquals("/chunk", _uriOrStatus);
        Assert.assertEquals("HTTP/1.1", _versionOrReason);
        Assert.assertEquals("X", _content);

        Assert.assertTrue(_headerCompleted);
        Assert.assertTrue(_messageCompleted);
    }

    
    void testContentLengthThenTransferEncodingChunked() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "POST /chunk HTTP/1.1\r\n"
                        ~ "Host: localhost\r\n"
                        ~ "Content-Length: 1\r\n"
                        ~ "Transfer-Encoding: chunked\r\n"
                        ~ "\r\n"
                        ~ "1\r\n"
                        ~ "X\r\n"
                        ~ "0\r\n"
                        ~ "\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parseAll(parser, buffer);

        Assert.assertEquals("POST", _methodOrVersion);
        Assert.assertEquals("/chunk", _uriOrStatus);
        Assert.assertEquals("HTTP/1.1", _versionOrReason);
        Assert.assertEquals("X", _content);

        Assert.assertTrue(_headerCompleted);
        Assert.assertTrue(_messageCompleted);
    }

    
    void testHost() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET / HTTP/1.1\r\n"
                        ~ "Host: host\r\n"
                        ~ "Connection: close\r\n"
                        ~ "\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parser.parseNext(buffer);
        Assert.assertEquals("host", _host);
        Assert.assertEquals(0, _port);
    }

    
    void testUriHost11() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET http://host/ HTTP/1.1\r\n"
                        ~ "Connection: close\r\n"
                        ~ "\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parser.parseNext(buffer);
        Assert.assertEquals("No Host", _bad);
        Assert.assertEquals("http://host/", _uriOrStatus);
        Assert.assertEquals(0, _port);
    }

    
    void testUriHost10() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET http://host/ HTTP/1.0\r\n"
                        ~ "\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parser.parseNext(buffer);
        // Assert.assertNull(_bad);
        Assert.assertEquals("http://host/", _uriOrStatus);
        Assert.assertEquals(0, _port);
    }

    
    void testNoHost() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET / HTTP/1.1\r\n"
                        ~ "Connection: close\r\n"
                        ~ "\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parser.parseNext(buffer);
        Assert.assertEquals("No Host", _bad);
    }

    
    void testIPHost() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET / HTTP/1.1\r\n"
                        ~ "Host: 192.168.0.1\r\n"
                        ~ "Connection: close\r\n"
                        ~ "\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parser.parseNext(buffer);
        Assert.assertEquals("192.168.0.1", _host);
        Assert.assertEquals(0, _port);
    }

    
    void testIPv6Host() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET / HTTP/1.1\r\n"
                        ~ "Host: [::1]\r\n"
                        ~ "Connection: close\r\n"
                        ~ "\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parser.parseNext(buffer);
        Assert.assertEquals("[::1]", _host);
        Assert.assertEquals(0, _port);
    }

    
    void testBadIPv6Host() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET / HTTP/1.1\r\n"
                        ~ "Host: [::1\r\n"
                        ~ "Connection: close\r\n"
                        ~ "\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parser.parseNext(buffer);
        Assert.assertContain(_bad, "Bad");
    }

    
    void testHostPort() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET / HTTP/1.1\r\n"
                        ~ "Host: myhost:8888\r\n"
                        ~ "Connection: close\r\n"
                        ~ "\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parser.parseNext(buffer);
        Assert.assertEquals("myhost", _host);
        Assert.assertEquals(8888, _port);
    }

    
    void testHostBadPort() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET / HTTP/1.1\r\n"
                        ~ "Host: myhost:testBadPort\r\n"
                        ~ "Connection: close\r\n"
                        ~ "\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parser.parseNext(buffer);
        Assert.assertContain(_bad, "Bad Host");
    }

    
    void testIPHostPort() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET / HTTP/1.1\r\n"
                        ~ "Host: 192.168.0.1:8888\r\n"
                        ~ "Connection: close\r\n"
                        ~ "\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parser.parseNext(buffer);
        Assert.assertEquals("192.168.0.1", _host);
        Assert.assertEquals(8888, _port);
    }

    
    void testIPv6HostPort() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET / HTTP/1.1\r\n"
                        ~ "Host: [::1]:8888\r\n"
                        ~ "Connection: close\r\n"
                        ~ "\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parser.parseNext(buffer);
        Assert.assertEquals("[::1]", _host);
        Assert.assertEquals(8888, _port);
    }

    
    void testEmptyHostPort() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET / HTTP/1.1\r\n"
                        ~ "Host:\r\n"
                        ~ "Connection: close\r\n"
                        ~ "\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parser.parseNext(buffer);
        // Assert.assertEquals(null, _host);
        // Assert.assertEquals(null, _bad);
    }

    
    
    void testCachedField() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET / HTTP/1.1\r\n" ~
                        "Host: www.smh.com.au\r\n" ~
                        "\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parseAll(parser, buffer);
        HttpField field = parser.getCachedField("Host: www.smh.com.au");
        // assert(field !is null);
        // Assert.assertEquals("www.smh.com.au", field.getValue());
        field = _fields.get(0);

        buffer.position(0);
        parseAll(parser, buffer);
        Assert.assertTrue(field == _fields.get(0));
    }

    
    void testParseRequest() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "GET / HTTP/1.1\r\n" ~
                        "Host: localhost\r\n" ~
                        "Header1: value1\r\n" ~
                        "Connection: close\r\n" ~
                        "Accept-Encoding: gzip, deflated\r\n" ~
                        "Accept: unknown\r\n" ~
                        "\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parser.parseNext(buffer);

        Assert.assertEquals("GET", _methodOrVersion);
        Assert.assertEquals("/", _uriOrStatus);
        Assert.assertEquals("HTTP/1.1", _versionOrReason);
        Assert.assertEquals("Host", _hdr[0]);
        Assert.assertEquals("localhost", _val[0]);
        Assert.assertEquals("Connection", _hdr[2]);
        Assert.assertEquals("close", _val[2]);
        Assert.assertEquals("Accept-Encoding", _hdr[3]);
        Assert.assertEquals("gzip, deflated", _val[3]);
        Assert.assertEquals("Accept", _hdr[4]);
        Assert.assertEquals("unknown", _val[4]);
    }

    
    void testHTTP2Preface() {
        ByteBuffer buffer = BufferUtils.toBuffer(
                "PRI * HTTP/2.0\r\n" ~
                        "\r\n" ~
                        "SM\r\n" ~
                        "\r\n");

        HttpParser.RequestHandler handler = new Handler();
        HttpParser parser = new HttpParser(handler);
        parseAll(parser, buffer);

        Assert.assertTrue(_headerCompleted);
        Assert.assertTrue(_messageCompleted);
        Assert.assertEquals("PRI", _methodOrVersion);
        Assert.assertEquals("*", _uriOrStatus);
        Assert.assertEquals("HTTP/2.0", _versionOrReason);
        Assert.assertEquals(-1, _headers);
        // Assert.assertEquals(null, _bad);
    }

    
    void init() {
        _bad = null;
        _content = null;
        _methodOrVersion = null;
        _uriOrStatus = null;
        _versionOrReason = null;
        _hdr = null;
        _val = null;
        _headers = 0;
        _headerCompleted = false;
        _messageCompleted = false;
        _complianceViolation.clear();
    }

    private class Handler : HttpParser.RequestHandler, HttpParser.ResponseHandler, HttpParser.ComplianceHandler {
        
        bool content(ByteBuffer buffer) {
            if (_content == null)
                _content = "";
            string c = BufferUtils.toString(buffer);
            _content = _content ~ c;
            buffer.position(buffer.limit());
            return false;
        }

        
        bool startRequest(string method, string uri, HttpVersion ver) {
            _fields.clear();
            _trailers.clear();
            _headers = -1;
            _hdr = new string[10];
            _val = new string[10];
            _methodOrVersion = method;
            _uriOrStatus = uri;
            _versionOrReason = ver == HttpVersion.Null ? null : ver.asString();
            _messageCompleted = false;
            _headerCompleted = false;
            _early = false;
            return false;
        }

        
        void parsedHeader(HttpField field) {
            _fields.add(field);
            _hdr[++_headers] = field.getName();
            _val[_headers] = field.getValue();

            if (typeid(field) == typeid(HostPortHttpField)) {
                HostPortHttpField hpfield = cast(HostPortHttpField) field;
                _host = hpfield.getHost();
                _port = hpfield.getPort();
            }
        }

        
        bool headerComplete() {
            _content = null;
            _headerCompleted = true;
            return false;
        }

        
        void parsedTrailer(HttpField field) {
            _trailers.add(field);
        }

        
        bool contentComplete() {
            return false;
        }

        
        bool messageComplete() {
            _messageCompleted = true;
            return true;
        }

        
        void badMessage(BadMessageException failure) {
            string reason = failure.getReason();
            _bad = reason.empty ? failure.getCode().to!string : reason;
        }

        void badMessage(int status, string reason)
        {
            
        }

        
        bool startResponse(HttpVersion ver, int status, string reason) {
            _fields.clear();
            _trailers.clear();
            _methodOrVersion = ver.asString();
            _uriOrStatus = status.to!string;
            _versionOrReason = reason;
            _headers = -1;
            _hdr = new string[10];
            _val = new string[10];
            _messageCompleted = false;
            _headerCompleted = false;
            return false;
        }

        
        void earlyEOF() {
            _early = true;
        }

        
        int getHeaderCacheSize() {
            return 512;
        }

        
        void onComplianceViolation(HttpCompliance compliance, HttpComplianceSection violation, string reason) {
            _complianceViolation.add(violation);
        }
    }
}
