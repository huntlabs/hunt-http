module test.codec.http2.model.MultipartParserTest;

import hunt.http.codec.http.model.BadMessageException;
import hunt.http.codec.http.model.MultipartParser;

import hunt.container.BufferUtils;
import hunt.container.ByteBuffer;
import hunt.container.ArrayList;
import hunt.container.List;
import hunt.logging;
import hunt.string;
import hunt.util.Assert;

import std.algorithm;
import std.conv;

alias State = MultipartParser.State;

alias assertTrue = Assert.assertTrue;
alias assertFalse = Assert.assertFalse;
alias assertThat = Assert.assertThat;
alias assertEquals = Assert.assertEquals;
alias assertNull = Assert.assertNull;
alias assertContain = Assert.assertContain;


class MultipartParserTest {
    
    void testEmptyPreamble() {
        MultipartParser parser = new MultipartParser(new MultipartParserHandler(), "BOUNDARY");
        ByteBuffer data = BufferUtils.toBuffer("");

        parser.parse(data, false);
        assertThat(parser.getState(), State.PREAMBLE);
    }

    
    void testNoPreamble() {
        MultipartParser parser = new MultipartParser(new MultipartParserHandler(), "BOUNDARY");
        ByteBuffer data = BufferUtils.toBuffer("");

        data = BufferUtils.toBuffer("--BOUNDARY   \r\n");
        parser.parse(data, false);
        assertTrue(parser.isState(State.BODY_PART));
        assertThat(data.remaining(), 0);
    }

    
    void testPreamble() {
        MultipartParser parser = new MultipartParser(new MultipartParserHandler(), "BOUNDARY");
        ByteBuffer data;

        data = BufferUtils.toBuffer("This is not part of a part\r\n");
        parser.parse(data, false);
        assertThat(parser.getState(), State.PREAMBLE);
        assertThat(data.remaining(), 0);

        data = BufferUtils.toBuffer("More data that almost includes \n--BOUNDARY but no CR before.");
        parser.parse(data, false);
        assertThat(parser.getState(), State.PREAMBLE);
        assertThat(data.remaining(), 0);

        data = BufferUtils.toBuffer("Could be a boundary \r\n--BOUNDAR");
        parser.parse(data, false);
        assertThat(parser.getState(), State.PREAMBLE);
        assertThat(data.remaining(), 0);

        data = BufferUtils.toBuffer("but not it isn't \r\n--BOUN");
        parser.parse(data, false);
        assertThat(parser.getState(), State.PREAMBLE);
        assertThat(data.remaining(), 0);

        data = BufferUtils.toBuffer("DARX nor is this");
        parser.parse(data, false);
        assertThat(parser.getState(), State.PREAMBLE);
        assertThat(data.remaining(), 0);
    }

    
    void testPreambleCompleteBoundary() {
        MultipartParser parser = new MultipartParser(new MultipartParserHandler(), "BOUNDARY");
        ByteBuffer data;

        data = BufferUtils.toBuffer("This is not part of a part\r\n--BOUNDARY  \r\n");
        parser.parse(data, false);
        assertThat(parser.getState(), State.BODY_PART);
        assertThat(data.remaining(), 0);
    }

    
    void testPreambleSplitBoundary() {
        MultipartParser parser = new MultipartParser(new MultipartParserHandler(), "BOUNDARY");
        ByteBuffer data;

        data = BufferUtils.toBuffer("This is not part of a part\r\n");
        parser.parse(data, false);
        assertThat(parser.getState(), State.PREAMBLE);
        assertThat(data.remaining(), 0);
        data = BufferUtils.toBuffer("-");
        parser.parse(data, false);
        assertThat(parser.getState(), State.PREAMBLE);
        assertThat(data.remaining(), 0);
        data = BufferUtils.toBuffer("-");
        parser.parse(data, false);
        assertThat(parser.getState(), State.PREAMBLE);
        assertThat(data.remaining(), 0);
        data = BufferUtils.toBuffer("B");
        parser.parse(data, false);
        assertThat(parser.getState(), State.PREAMBLE);
        assertThat(data.remaining(), 0);
        data = BufferUtils.toBuffer("OUNDARY-");
        parser.parse(data, false);
        assertThat(parser.getState(), State.DELIMITER_CLOSE);
        assertThat(data.remaining(), 0);
        data = BufferUtils.toBuffer("ignore\r");
        parser.parse(data, false);
        assertThat(parser.getState(), State.DELIMITER_PADDING);
        assertThat(data.remaining(), 0);
        data = BufferUtils.toBuffer("\n");
        parser.parse(data, false);
        assertThat(parser.getState(), State.BODY_PART);
        assertThat(data.remaining(), 0);
    }

    
    void testFirstPartNoFields() {
        MultipartParser parser = new MultipartParser(new MultipartParserHandler(), "BOUNDARY");
        ByteBuffer data = BufferUtils.toBuffer("");

        data = BufferUtils.toBuffer("--BOUNDARY\r\n\r\n");
        parser.parse(data, false);
        assertThat(parser.getState(), State.FIRST_OCTETS);
        assertThat(data.remaining(), 0);
    }

    
    void testFirstPartFields() {
        TestHandler handler = new class TestHandler {
            override
            bool headerComplete() {
                super.headerComplete();
                return true;
            }
        };
        MultipartParser parser = new MultipartParser(handler, "BOUNDARY");

        ByteBuffer data = BufferUtils.toBuffer("");

        data = BufferUtils.toBuffer("--BOUNDARY\r\n"
                ~ "name0: value0\r\n"
                ~ "name1 :value1 \r\n"
                ~ "name2:value\r\n"
                ~ " 2\r\n"
                ~ "\r\n"
                ~ "Content");
        parser.parse(data, false);
        assertThat(parser.getState(), State.FIRST_OCTETS);
        assertThat(data.remaining(), 7);
        assertThat(handler.fields.toArray(), Matchers.contains("name0: value0", "name1: value1", "name2: value 2", "<<COMPLETE>>"));
    }

    
    void testFirstPartNoContent() {
        TestHandler handler = new TestHandler();
        MultipartParser parser = new MultipartParser(handler, "BOUNDARY");

        ByteBuffer data = BufferUtils.toBuffer("");

        data = BufferUtils.toBuffer("--BOUNDARY\r\n"
                ~ "name: value\r\n"
                ~ "\r\n"
                ~ "\r\n"
                ~ "--BOUNDARY");
        parser.parse(data, false);
        assertThat(parser.getState(), State.DELIMITER);
        assertThat(data.remaining(), 0);
        assertThat(handler.fields.toArray(), Matchers.contains("name: value", "<<COMPLETE>>"));
        assertThat(handler.getContent(), ["<<LAST>>"]);
    }

    
    void testFirstPartNoContentNoCRLF() {
        TestHandler handler = new TestHandler();
        MultipartParser parser = new MultipartParser(handler, "BOUNDARY");

        ByteBuffer data = BufferUtils.toBuffer("");

        data = BufferUtils.toBuffer("--BOUNDARY\r\n"
                ~ "name: value\r\n"
                ~ "\r\n"
                ~ "--BOUNDARY");
        parser.parse(data, false);
        assertThat(parser.getState(), State.DELIMITER);
        assertThat(data.remaining(), 0);
        assertThat(handler.fields.toArray(), Matchers.contains("name: value", "<<COMPLETE>>"));
        assertThat(handler.getContent(), ["<<LAST>>"]);

    }

    
    void testFirstPartContentLookingLikeNoCRLF() {
        TestHandler handler = new TestHandler();
        MultipartParser parser = new MultipartParser(handler, "BOUNDARY");

        ByteBuffer data = BufferUtils.toBuffer("");

        data = BufferUtils.toBuffer("--BOUNDARY\r\n"
                ~ "name: value\r\n"
                ~ "\r\n"
                ~ "-");
        parser.parse(data, false);
        data = BufferUtils.toBuffer("Content!");
        parser.parse(data, false);


        assertThat(parser.getState(), State.OCTETS);
        assertThat(data.remaining(), 0);
        assertThat(handler.fields.toArray(), Matchers.contains("name: value", "<<COMPLETE>>"));
        assertThat(handler.getContent(), Matchers.contains("-", "Content!"));
    }

    
    void testFirstPartPartialContent() {
        TestHandler handler = new TestHandler();
        MultipartParser parser = new MultipartParser(handler, "BOUNDARY");

        ByteBuffer data = BufferUtils.toBuffer("");

        data = BufferUtils.toBuffer("--BOUNDARY\r\n"
                ~ "name: value\n"
                ~ "\r\n"
                ~ "Hello\r\n");
        parser.parse(data, false);
        assertThat(parser.getState(), State.OCTETS);
        assertThat(data.remaining(), 0);
        assertThat(handler.fields.toArray(), Matchers.contains("name: value", "<<COMPLETE>>"));
        // FIXME: Needing refactor or cleanup -@zxp at 11/21/2018, 12:33:36 PM
        // 
        // assertThat(handler.getContent(), Matchers.contains("Hello"));
        assertThat(handler.getContent(), ["Hello"]);

        data = BufferUtils.toBuffer(
                "Now is the time for all good ment to come to the aid of the party.\r\n"
                        ~ "How now brown cow.\r\n"
                        ~ "The quick brown fox jumped over the lazy dog.\r\n"
                        ~ "this is not a --BOUNDARY\r\n");
        parser.parse(data, false);
        assertThat(parser.getState(), State.OCTETS);
        assertThat(data.remaining(), 0);
        assertThat(handler.fields.toArray(), Matchers.contains("name: value", "<<COMPLETE>>"));
        assertThat(handler.getContent(), Matchers.contains("Hello", "\r\n", "Now is the time for all good ment to come to the aid of the party.\r\n"
                ~ "How now brown cow.\r\n"
                ~ "The quick brown fox jumped over the lazy dog.\r\n"
                ~ "this is not a --BOUNDARY"));
    }

    
    void testFirstPartShortContent() {
        TestHandler handler = new TestHandler();
        MultipartParser parser = new MultipartParser(handler, "BOUNDARY");

        ByteBuffer data = BufferUtils.toBuffer("");

        data = BufferUtils.toBuffer("--BOUNDARY\r\n"
                ~ "name: value\n"
                ~ "\r\n"
                ~ "Hello\r\n"
                ~ "--BOUNDARY");
        parser.parse(data, false);
        assertThat(parser.getState(), State.DELIMITER);
        assertThat(data.remaining(), 0);
        assertThat(handler.fields.toArray(), Matchers.contains("name: value", "<<COMPLETE>>"));
        assertThat(handler.getContent(), Matchers.contains("Hello", "<<LAST>>"));
    }


    
    void testFirstPartLongContent() {
        TestHandler handler = new TestHandler();
        MultipartParser parser = new MultipartParser(handler, "BOUNDARY");

        ByteBuffer data = BufferUtils.toBuffer("");

        data = BufferUtils.toBuffer("--BOUNDARY\r\n"
                ~ "name: value\n"
                ~ "\r\n"
                ~ "Now is the time for all good ment to come to the aid of the party.\r\n"
                ~ "How now brown cow.\r\n"
                ~ "The quick brown fox jumped over the lazy dog.\r\n"
                ~ "\r\n"
                ~ "--BOUNDARY");
        parser.parse(data, false);
        assertThat(parser.getState(), State.DELIMITER);
        assertThat(data.remaining(), 0);
        assertThat(handler.fields.toArray(), Matchers.contains("name: value", "<<COMPLETE>>"));
        assertThat(handler.getContent(), Matchers.contains("Now is the time for all good ment to come to the aid of the party.\r\n"
                ~ "How now brown cow.\r\n"
                ~ "The quick brown fox jumped over the lazy dog.\r\n", "<<LAST>>"));
    }

    
    void testFirstPartLongContentNoCarriageReturn() {
        TestHandler handler = new TestHandler();
        MultipartParser parser = new MultipartParser(handler, "BOUNDARY");

        ByteBuffer data = BufferUtils.toBuffer("");

        //boundary still requires carriage return
        data = BufferUtils.toBuffer("--BOUNDARY\n"
                ~ "name: value\n"
                ~ "\n"
                ~ "Now is the time for all good men to come to the aid of the party.\n"
                ~ "How now brown cow.\n"
                ~ "The quick brown fox jumped over the lazy dog.\n"
                ~ "\r\n"
                ~ "--BOUNDARY");
        parser.parse(data, false);
        assertThat(parser.getState(), State.DELIMITER);
        assertThat(data.remaining(), 0);
        assertThat(handler.fields.toArray(), Matchers.contains("name: value", "<<COMPLETE>>"));
        assertThat(handler.getContent(), Matchers.contains("Now is the time for all good men to come to the aid of the party.\n"
                ~ "How now brown cow.\n"
                ~ "The quick brown fox jumped over the lazy dog.\n", "<<LAST>>"));
    }


    
    void testBinaryPart() {
        byte[] random = new byte[8192];
        import std.random;
        auto rnd = Random(2018);
        for(int i; i< random.length; i++)
            random[i] = cast(byte) uniform(byte.min, byte.max, rnd);
        // ThreadLocalRandom.current().nextBytes(random);
        ByteBuffer bytes = BufferUtils.allocate(cast(int)random.length);

        TestHandler handler = new class TestHandler {
            override
            bool content(ByteBuffer buffer, bool last) {
                BufferUtils.append(bytes, buffer);
                return last;
            }
        };
        MultipartParser parser = new MultipartParser(handler, "BOUNDARY");

        string preamble = "Blah blah blah\r\n--BOUNDARY\r\n\r\n";
        string epilogue = "\r\n--BOUNDARY\r\nBlah blah blah!\r\n";

        ByteBuffer data = BufferUtils.allocate(preamble.length + random.length + epilogue.length);
        BufferUtils.append(data, BufferUtils.toBuffer(preamble));
        BufferUtils.append(data, ByteBuffer.wrap(random));
        BufferUtils.append(data, BufferUtils.toBuffer(epilogue));

        parser.parse(data, true);
        assertThat(parser.getState(), State.DELIMITER);
        assertThat(data.remaining(), 19);
        assertThat(bytes.array(), random);
    }

    
    void testEpilogue() {
        TestHandler handler = new TestHandler();
        MultipartParser parser = new MultipartParser(handler, "BOUNDARY");

        ByteBuffer data = BufferUtils.toBuffer(""
                ~ "--BOUNDARY\r\n"
                ~ "name: value\n"
                ~ "\r\n"
                ~ "Hello\r\n"
                ~ "--BOUNDARY--"
                ~ "epilogue here:"
                ~ "\r\n"
                ~ "--BOUNDARY--"
                ~ "\r\n"
                ~ "--BOUNDARY");


        parser.parse(data, false);
        assertThat(parser.getState(), State.DELIMITER);
        assertThat(handler.fields.toArray(), Matchers.contains("name: value", "<<COMPLETE>>"));
        assertThat(handler.getContent(), Matchers.contains("Hello", "<<LAST>>"));

        parser.parse(data, true);
        assertThat(parser.getState(), State.END);
    }


    
    void testMultipleContent() {
        TestHandler handler = new TestHandler();
        MultipartParser parser = new MultipartParser(handler, "BOUNDARY");

        ByteBuffer data = BufferUtils.toBuffer(""
                ~ "--BOUNDARY\r\n"
                ~ "name: value\n"
                ~ "\r\n"
                ~ "Hello"
                ~ "\r\n"
                ~ "--BOUNDARY\r\n"
                ~ "powerLevel: 9001\n"
                ~ "\r\n"
                ~ "secondary"
                ~ "\r\n"
                ~ "content"
                ~ "\r\n--BOUNDARY--"
                ~ "epilogue here");

        /* Test First Content Section */
        parser.parse(data, false);
        assertThat(parser.getState(), State.DELIMITER);
        assertThat(handler.fields.toArray(), Matchers.contains("name: value", "<<COMPLETE>>"));
        assertThat(handler.getContent(), Matchers.contains("Hello", "<<LAST>>"));

        /* Test Second Content Section */
        parser.parse(data, false);
        assertThat(parser.getState(), State.DELIMITER);
        assertThat(handler.fields.toArray(), Matchers.contains("name: value", "<<COMPLETE>>", "powerLevel: 9001", "<<COMPLETE>>"));
        assertThat(handler.getContent(), Matchers.contains("Hello", "<<LAST>>", "secondary\r\ncontent", "<<LAST>>"));

        /* Test Progression to END State */
        parser.parse(data, true);
        assertThat(parser.getState(), State.END);
        assertThat(data.remaining(), 0);
    }


    
    void testCrAsLineTermination() {
        TestHandler handler = new class TestHandler {
            override
            bool messageComplete() {
                return true;
            }

            override
            bool content(ByteBuffer buffer, bool last) {
                super.content(buffer, last);
                return false;
            }
        };
        MultipartParser parser = new MultipartParser(handler, "AaB03x");

        ByteBuffer data = BufferUtils.toBuffer(
                "--AaB03x\r\n" ~
                        "content-disposition: form-data; name=\"field1\"\r\n" ~
                        "\r" ~
                        "Joe Blow\r\n" ~
                        "--AaB03x--\r\n");


        try {
            parser.parse(data, true);
            Assert.fail("Invalid End of Line");
        } catch (BadMessageException e) {
            assertTrue(e.msg.canFind("Bad EOL"));
        }
    }


    
    void splitTest() {
        TestHandler handler = new class TestHandler {
            override
            bool messageComplete() {
                return true;
            }

            override
            bool content(ByteBuffer buffer, bool last) {
                super.content(buffer, last);
                return false;
            }
        };

        MultipartParser parser = new MultipartParser(handler, "---------------------------9051914041544843365972754266");
        ByteBuffer data = BufferUtils.toBuffer("" ~
                "POST / HTTP/1.1\n" ~
                "Host: localhost:8000\n" ~
                "User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux i686; rv:29.0) Gecko/20100101 Firefox/29.0\n" ~
                "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\n" ~
                "Accept-Language: en-US,en;q=0.5\n" ~
                "Accept-Encoding: gzip, deflate\n" ~
                "Cookie: __atuvc=34%7C7; permanent=0; _gitlab_session=226ad8a0be43681acf38c2fab9497240; __profilin=p%3Dt; request_method=GET\n" ~
                "Connection: keep-alive\n" ~
                "Content-Type: multipart/form-data; boundary=---------------------------9051914041544843365972754266\n" ~
                "Content-Length: 554\n" ~
                "\r\n" ~
                "-----------------------------9051914041544843365972754266\n" ~
                "Content-Disposition: form-data; name=\"text\"\n" ~
                "\n" ~
                "text default\r\n" ~
                "-----------------------------9051914041544843365972754266\n" ~
                "Content-Disposition: form-data; name=\"file1\"; filename=\"a.txt\"\n" ~
                "Content-Type: text/plain\n" ~
                "\n" ~
                "Content of a.txt.\n" ~
                "\r\n" ~
                "-----------------------------9051914041544843365972754266\n" ~
                "Content-Disposition: form-data; name=\"file2\"; filename=\"a.html\"\n" ~
                "Content-Type: text/html\n" ~
                "\n" ~
                "<!DOCTYPE html><title>Content of a.html.</title>\n" ~
                "\r\n" ~
                "-----------------------------9051914041544843365972754266\n" ~
                "Field1: value1\n" ~
                "Field2: value2\n" ~
                "Field3: value3\n" ~
                "Field4: value4\n" ~
                "Field5: value5\n" ~
                "Field6: value6\n" ~
                "Field7: value7\n" ~
                "Field8: value8\n" ~
                "Field9: value\n" ~
                " 9\n" ~
                "\r\n" ~
                "-----------------------------9051914041544843365972754266\n" ~
                "Field1: value1\n" ~
                "\r\n" ~
                "But the amount of denudation which the strata have\n" ~
                "in many places suffered, independently of the rate\n" ~
                "of accumulation of the degraded matter, probably\n" ~
                "offers the best evidence of the lapse of time. I remember\n" ~
                "having been much struck with the evidence of\n" ~
                "denudation, when viewing volcanic islands, which\n" ~
                "have been worn by the waves and pared all round\n" ~
                "into perpendicular cliffs of one or two thousand feet\n" ~
                "in height; for the gentle slope of the lava-streams,\n" ~
                "due to their formerly liquid state, showed at a glance\n" ~
                "how far the hard, rocky beds had once extended into\n" ~
                "the open ocean.\n" ~
                "\r\n" ~
                "-----------------------------9051914041544843365972754266--" ~
                "===== ajlkfja;lkdj;lakjd;lkjf ==== epilogue here  ==== kajflajdfl;kjafl;kjl;dkfja ====\n\r\n\r\r\r\n\n\n");


        int length = data.remaining();
        for (int i = 0; i < length - 1; i++) {
            //partition 0 to i
            ByteBuffer dataSeg = data.slice();
            dataSeg.position(0);
            dataSeg.limit(i);
            assertThat("First " ~ i.to!string(), parser.parse(dataSeg, false), false);

            //partition i
            dataSeg = data.slice();
            dataSeg.position(i);
            dataSeg.limit(i + 1);
            assertThat("Second " ~ i.to!string(), parser.parse(dataSeg, false), false);

            //partition i to length
            dataSeg = data.slice();
            dataSeg.position(i + 1);
            dataSeg.limit(length);
            assertThat("Third " ~ i.to!string(), parser.parse(dataSeg, true), true);

            assertThat(handler.fields.toArray(), Matchers.contains("Content-Disposition: form-data; name=\"text\"", "<<COMPLETE>>"
                    , "Content-Disposition: form-data; name=\"file1\"; filename=\"a.txt\""
                    , "Content-Type: text/plain", "<<COMPLETE>>"
                    , "Content-Disposition: form-data; name=\"file2\"; filename=\"a.html\""
                    , "Content-Type: text/html", "<<COMPLETE>>"
                    , "Field1: value1", "Field2: value2", "Field3: value3"
                    , "Field4: value4", "Field5: value5", "Field6: value6"
                    , "Field7: value7", "Field8: value8", "Field9: value 9", "<<COMPLETE>>"
                    , "Field1: value1", "<<COMPLETE>>"));


            assertThat(handler.contentString(), "text default" ~ "<<LAST>>"
                    ~ "Content of a.txt.\n" ~ "<<LAST>>"
                    ~ "<!DOCTYPE html><title>Content of a.html.</title>\n" ~ "<<LAST>>"
                    ~ "<<LAST>>"
                    ~ "But the amount of denudation which the strata have\n" ~
                    "in many places suffered, independently of the rate\n" ~
                    "of accumulation of the degraded matter, probably\n" ~
                    "offers the best evidence of the lapse of time. I remember\n" ~
                    "having been much struck with the evidence of\n" ~
                    "denudation, when viewing volcanic islands, which\n" ~
                    "have been worn by the waves and pared all round\n" ~
                    "into perpendicular cliffs of one or two thousand feet\n" ~
                    "in height; for the gentle slope of the lava-streams,\n" ~
                    "due to their formerly liquid state, showed at a glance\n" ~
                    "how far the hard, rocky beds had once extended into\n" ~
                    "the open ocean.\n" ~ "<<LAST>>");

            handler.clear();
            parser.reset();
        }
    }


    
    void testGeneratedForm() {
        TestHandler handler = new class TestHandler {
            override
            bool messageComplete() {
                return true;
            }

            override
            bool content(ByteBuffer buffer, bool last) {
                super.content(buffer, last);
                return false;
            }

            override
            bool headerComplete() {
                return false;
            }
        };

        MultipartParser parser = new MultipartParser(handler, "WebKitFormBoundary7MA4YWf7OaKlSxkTrZu0gW");
        ByteBuffer data = BufferUtils.toBuffer(""
                ~ "Content-Type: multipart/form-data; boundary=WebKitFormBoundary7MA4YWf7OaKlSxkTrZu0gW\r\n" ~
                "\r\n" ~
                "--WebKitFormBoundary7MA4YWf7OaKlSxkTrZu0gW\r\n" ~
                "Content-Disposition: form-data; name=\"part1\"\r\n" ~
                "\n" ~
                "wNfﾐxVam﾿t\r\n" ~
                "--WebKitFormBoundary7MA4YWf7OaKlSxkTrZu0gW\n" ~
                "Content-Disposition: form-data; name=\"part2\"\r\n" ~
                "\r\n" ~
                "&ﾳﾺ￙￹ￖￃO\r\n" ~
                "--WebKitFormBoundary7MA4YWf7OaKlSxkTrZu0gW--");

        parser.parse(data, true);
        assertThat(parser.getState(), State.END);
        assertThat(handler.fields.size(), 2);

    }

}





class TestHandler : MultipartParserHandler {
    List!(string) fields;
    List!(string) _content;

    this() {
        fields = new ArrayList!(string)();
        _content = new ArrayList!(string)();
    }

    string[] getContent() {
        return _content.toArray();
    }

    override
    void parsedField(string name, string value) {
        fields.add(name ~ ": " ~ value);
    }

    string contentString() {
        StringBuilder sb = new StringBuilder();
        foreach (string s ; _content) sb.append(s);
        return sb.toString();
    }

    override
    bool headerComplete() {
        fields.add("<<COMPLETE>>");
        return false;
    }

    override
    bool content(ByteBuffer buffer, bool last) {
        if (BufferUtils.hasContent(buffer))
            _content.add(BufferUtils.toString(buffer));
        if (last)
            _content.add("<<LAST>>");
        return last;
    }

    void clear() {
        fields.clear();
        _content.clear();
    }

}