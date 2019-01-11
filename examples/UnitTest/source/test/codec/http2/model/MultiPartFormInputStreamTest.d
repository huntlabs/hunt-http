module test.codec.http2.model.MultipartFormInputStreamTest;

import hunt.http.codec.http.model.MultiException;
import hunt.http.codec.http.model.MultipartConfig;
import hunt.http.codec.http.model.MultipartParser;
import hunt.http.codec.http.model.MultipartFormInputStream;

import hunt.collection;
import hunt.util.DateTime;
import hunt.io;
import hunt.Exceptions;
import hunt.logging;
import hunt.text.Common;
import hunt.Assert;

import std.algorithm;
import std.array;
import std.base64;
import std.conv;
import std.datetime;
import std.file;
import std.path;
import std.regex;
import std.string;
import std.uni;


alias assertTrue = Assert.assertTrue;
alias assertFalse = Assert.assertFalse;
alias assertThat = Assert.assertThat;
alias assertEquals = Assert.assertEquals;
alias assertNull = Assert.assertNull;
alias assertNotNull = Assert.assertNotNull;
alias assertContain = Assert.assertContain;


/**
 * MultiPartInputStreamTest
 */
class MultipartFormInputStreamTest {
    private enum string FILENAME = "stuff.txt";
    protected string _contentType = "multipart/form-data, boundary=AaB03x";
    protected string _multi;
    protected string _dirname;
    protected string _tmpDir;

    this() {
        _multi = createMultipartRequestString(FILENAME);
        _dirname = tempDir() ~ dirSeparator ~ "myfiles-" ~ DateTimeHelper.currentTimeMillis().to!string();
        _tmpDir = this._dirname;
    }
    
    void testBadMultiPartRequest() {
        string boundary = "X0Y0";
        string str = "--" ~ boundary ~ "\r\n" ~
                "Content-Disposition: form-data; name=\"fileup\"; filename=\"test.upload\"\r\n" ~
                "Content-Type: application/octet-stream\r\n\r\n" ~
                "How now brown cow." ~
                "\r\n--" ~ boundary ~ "-\r\n"
                ~ "Content-Disposition: form-data; name=\"fileup\"; filename=\"test.upload\"\r\n"
                ~ "\r\n";

        MultipartConfig config = new MultipartConfig(_dirname, 1024, 3072, 50);
        MultipartFormInputStream mpis = new MultipartFormInputStream(new ByteArrayInputStream(cast(byte[])str),
                "multipart/form-data, boundary=" ~ boundary,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        try {
            mpis.getParts();
            Assert.fail("Incomplete Multipart");
        } catch (IOException e) {
            assertTrue(e.msg.startsWith("Incomplete"));
        }
    }

    void testFinalBoundaryOnly() {
        string delimiter = "\r\n";
        string boundary = "MockMultiPartTestBoundary";

        // Malformed multipart request body containing only an arbitrary string of text, followed by the final boundary marker, delimited by empty lines.
        string str = delimiter ~ "Hello world" ~
                        delimiter ~        // Two delimiter markers, which make an empty line.
                        delimiter ~
                        "--" ~ boundary ~ "--" ~ delimiter;

        MultipartConfig config = new MultipartConfig(_dirname, 1024, 3072, 50);
        MultipartFormInputStream mpis = new MultipartFormInputStream(new ByteArrayInputStream(cast(byte[])str),
                "multipart/form-data, boundary=" ~ boundary,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        Part[] parts = mpis.getParts();
        assertTrue(mpis.getParts().empty());
    }


    
    void testEmpty() {
        string delimiter = "\r\n";
        string boundary = "MockMultiPartTestBoundary";

        string str = delimiter ~ "--" ~ boundary ~ "--" ~ delimiter;

        MultipartConfig config = new MultipartConfig(_dirname, 1024, 3072, 50);
        MultipartFormInputStream mpis = new MultipartFormInputStream(new ByteArrayInputStream(cast(byte[])str),
                "multipart/form-data, boundary=" ~ boundary,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        assertTrue(mpis.getParts().empty());
    }

    
    void testNoBoundaryRequest() {
        string str = "--\r\n" ~
                "Content-Disposition: form-data; name=\"fileName\"\r\n" ~
                "Content-Type: text/plain; charset=US-ASCII\r\n" ~
                "Content-Transfer-Encoding: 8bit\r\n" ~
                "\r\n" ~
                "abc\r\n" ~
                "--\r\n" ~
                "Content-Disposition: form-data; name=\"desc\"\r\n" ~
                "Content-Type: text/plain; charset=US-ASCII\r\n" ~
                "Content-Transfer-Encoding: 8bit\r\n" ~
                "\r\n" ~
                "123\r\n" ~
                "--\r\n" ~
                "Content-Disposition: form-data; name=\"title\"\r\n" ~
                "Content-Type: text/plain; charset=US-ASCII\r\n" ~
                "Content-Transfer-Encoding: 8bit\r\n" ~
                "\r\n" ~
                "ttt\r\n" ~
                "--\r\n" ~
                "Content-Disposition: form-data; name=\"datafile5239138112980980385.txt\"; filename=\"datafile5239138112980980385.txt\"\r\n" ~
                "Content-Type: application/octet-stream; charset=ISO-8859-1\r\n" ~
                "Content-Transfer-Encoding: binary\r\n" ~
                "\r\n" ~
                "000\r\n" ~
                "----\r\n";

        MultipartConfig config = new MultipartConfig(_dirname, 1024, 3072, 50);
        MultipartFormInputStream mpis = new MultipartFormInputStream(new ByteArrayInputStream(cast(byte[])str),
                "multipart/form-data",
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        Part[] parts = mpis.getParts();
        assertThat(parts.length, 4);

        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        Part fileName = mpis.getPart("fileName");
        assert(fileName !is null);
        assertThat(fileName.getSize(), 3L);
        IOUtils.copy(fileName.getInputStream(), baos);
        assertThat(baos.toString(), "abc");

        baos = new ByteArrayOutputStream();
        Part desc = mpis.getPart("desc");
        assert(desc !is null);
        assertThat(desc.getSize(), 3L);
        IOUtils.copy(desc.getInputStream(), baos);
        assertThat(baos.toString(), "123");

        baos = new ByteArrayOutputStream();
        Part title = mpis.getPart("title");
        assert(title !is null);
        assertThat(title.getSize(), 3L);
        IOUtils.copy(title.getInputStream(), baos);
        assertThat(baos.toString(), "ttt");
    }

    
    void testNonMultiPartRequest() {
        MultipartConfig config = new MultipartConfig(_dirname, 1024, 3072, 50);
        MultipartFormInputStream mpis = new MultipartFormInputStream(new ByteArrayInputStream(cast(byte[])_multi),
                "Content-type: text/plain",
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        assertTrue(mpis.getParts().empty());
    }

    
    void testNoBody() {
        string bodyContent = "";

        MultipartConfig config = new MultipartConfig(_dirname, 1024, 3072, 50);
        MultipartFormInputStream mpis = new MultipartFormInputStream(new ByteArrayInputStream(cast(byte[])bodyContent),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        try {
            mpis.getParts();
            Assert.fail("Missing initial multi part boundary");
        } catch (IOException e) {
            assertTrue(e.msg.canFind("Missing initial multi part boundary"));
        }
    }

    // void testBodyAlreadyConsumed() {
    //     ServletInputStream input = new ServletInputStream() {

    //         override
    //         bool isFinished() {
    //             return true;
    //         }

    //         override
    //         bool isReady() {
    //             return false;
    //         }

    //         override
    //         void setReadListener(ReadListener readListener) {
    //         }

    //         override
    //         int read() {
    //             return 0;
    //         }

    //     };

    //     MultipartConfig config = new MultipartConfig(_dirname, 1024, 3072, 50);
    //     MultipartFormInputStream mpis = new MultipartFormInputStream(input,
    //             _contentType,
    //             config,
    //             _tmpDir);
    //     mpis.setDeleteOnExit(true);
    //     Part[] parts = mpis.getParts();
    //     assertEquals(0, parts.length);
    // }
    
    void testWhitespaceBodyWithCRLF() {
        string whitespace = "              \n\n\n\r\n\r\n\r\n\r\n";
        MultipartConfig config = new MultipartConfig(_dirname, 1024, 3072, 50);
        MultipartFormInputStream mpis = new MultipartFormInputStream(new ByteArrayInputStream(cast(byte[])whitespace),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        try {
            mpis.getParts();
            Assert.fail("Missing initial multi part boundary");
        } catch (IOException e) {
            assertTrue(e.msg.canFind("Missing initial multi part boundary"));
        }
    }

    
    void testWhitespaceBody() {
        string whitespace = " ";

        MultipartConfig config = new MultipartConfig(_dirname, 1024, 3072, 50);
        MultipartFormInputStream mpis = new MultipartFormInputStream(new ByteArrayInputStream(cast(byte[])whitespace),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        try {
            mpis.getParts();
            Assert.fail("Multipart missing body");
        } catch (IOException e) {
            assertTrue(e.msg.startsWith("Missing initial"));
        }
    }

    
    void testLeadingWhitespaceBodyWithCRLF() {
        string bodyContent = "              \n\n\n\r\n\r\n\r\n\r\n" ~
                "--AaB03x\r\n" ~
                "content-disposition: form-data; name=\"field1\"\r\n" ~
                "\r\n" ~
                "Joe Blow\r\n" ~
                "--AaB03x\r\n" ~
                "content-disposition: form-data; name=\"stuff\"; filename=\"" ~ "foo.txt" ~ "\"\r\n" ~
                "Content-Type: text/plain\r\n" ~
                "\r\n" ~ "aaaa" ~
                "bbbbb" ~ "\r\n" ~
                "--AaB03x--\r\n";


        MultipartConfig config = new MultipartConfig(_dirname, 1024, 3072, 50);
        MultipartFormInputStream mpis = new MultipartFormInputStream(new ByteArrayInputStream(cast(byte[])bodyContent),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);

        Part[] parts = mpis.getParts();
        assert(parts.length>0);
        assertThat(parts.length, 2);
        Part field1 = mpis.getPart("field1");
        assert(field1 !is null);
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        IOUtils.copy(field1.getInputStream(), baos);
        assertThat(baos.toString(), "Joe Blow");

        Part stuff = mpis.getPart("stuff");
        assert(stuff !is null);
        baos = new ByteArrayOutputStream();
        IOUtils.copy(stuff.getInputStream(), baos);
        assertTrue(baos.toString().canFind("aaaa"));
    }


    
    void testLeadingWhitespaceBodyWithoutCRLF() {
        string bodyContent = "            " ~
                "--AaB03x\r\n" ~
                "content-disposition: form-data; name=\"field1\"\r\n" ~
                "\r\n" ~
                "Joe Blow\r\n" ~
                "--AaB03x\r\n" ~
                "content-disposition: form-data; name=\"stuff\"; filename=\"" ~ "foo.txt" ~ "\"\r\n" ~
                "Content-Type: text/plain\r\n" ~
                "\r\n" ~ "aaaa" ~
                "bbbbb" ~ "\r\n" ~
                "--AaB03x--\r\n";

        MultipartConfig config = new MultipartConfig(_dirname, 1024, 3072, 50);
        MultipartFormInputStream mpis = new MultipartFormInputStream(new ByteArrayInputStream(cast(byte[])bodyContent),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);

        Part[] parts = mpis.getParts();
        assert(parts.length>0);
        assertThat(parts.length, 1);

        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        Part stuff = mpis.getPart("stuff");
        assert(stuff !is null);
        baos = new ByteArrayOutputStream();
        IOUtils.copy(stuff.getInputStream(), baos);
        assertTrue(baos.toString().canFind("bbbbb"));
    }

    void testNoLimits() {
        MultipartConfig config = new MultipartConfig(_dirname);
        MultipartFormInputStream mpis = new MultipartFormInputStream(new ByteArrayInputStream(cast(byte[])_multi),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        Part[] parts = mpis.getParts();
        assertFalse(parts.empty());
    }
    
    void testRequestTooBig() {
        MultipartConfig config = new MultipartConfig(_dirname, 60, 100, 50);
        MultipartFormInputStream mpis = new MultipartFormInputStream(new ByteArrayInputStream(cast(byte[])_multi),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);

        try {
            mpis.getParts();
            Assert.fail("Request should have exceeded maxRequestSize");
        } catch (IllegalStateException e) {
            assertTrue(e.msg.startsWith("Request exceeds maxRequestSize"));
        }
    }

    void testRequestTooBigThrowsErrorOnGetParts() {
        MultipartConfig config = new MultipartConfig(_dirname, 60, 100, 50);
        MultipartFormInputStream mpis = new MultipartFormInputStream(new ByteArrayInputStream(cast(byte[])_multi),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        Part[] parts = null;

        //cause parsing
        try {
            parts = mpis.getParts();
            Assert.fail("Request should have exceeded maxRequestSize");
        } catch (IllegalStateException e) {
            assertTrue(e.msg.startsWith("Request exceeds maxRequestSize"));
        }

        //try again
        try {
            parts = mpis.getParts();
            Assert.fail("Request should have exceeded maxRequestSize");
        } catch (IllegalStateException e) {
            assertTrue(e.msg.startsWith("Request exceeds maxRequestSize"));
        }
    }

    
    void testFileTooBig() {
        MultipartConfig config = new MultipartConfig(_dirname, 40, 1024, 30);
        MultipartFormInputStream mpis = new MultipartFormInputStream(new ByteArrayInputStream(cast(byte[])_multi),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        Part[] parts = null;
        try {
            parts = mpis.getParts();
            Assert.fail("stuff.txt should have been larger than maxFileSize");
        } catch (IllegalStateException e) {
            assertTrue(e.msg.startsWith("Multipart Mime part"));
        }
    }

    
    void testFileTooBigThrowsErrorOnGetParts() {
        MultipartConfig config = new MultipartConfig(_dirname, 40, 1024, 30);
        MultipartFormInputStream mpis = new MultipartFormInputStream(new ByteArrayInputStream(cast(byte[])_multi),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        Part[] parts = null;
        try {
            parts = mpis.getParts(); //caused parsing
            Assert.fail("stuff.txt should have been larger than maxFileSize");
        } catch (Throwable e) {
            assertTrue(e.msg.startsWith("Multipart Mime part"));
        }

        //test again after the parsing
        try {
            parts = mpis.getParts(); //caused parsing
            Assert.fail("stuff.txt should have been larger than maxFileSize");
        } catch (IllegalStateException e) {
            assertTrue(e.msg.startsWith("Multipart Mime part"));
        }
    }

    
    void testPartFileNotDeleted() {
        MultipartConfig config = new MultipartConfig(_dirname, 1024, 3072, 50);
        MultipartFormInputStream mpis = new MultipartFormInputStream(
                new ByteArrayInputStream(cast(byte[])createMultipartRequestString("tptfd")),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        Part[] parts = mpis.getParts();

        MultipartFormInputStream.MultiPart part = cast(MultipartFormInputStream.MultiPart) mpis.getPart("stuff");
        string stuff = part.getFile();
        assert(!stuff.empty()); // longer than 100 bytes, should already be a tmp file
        part.write("tptfd.txt");
        string tptfd = _dirname ~ dirSeparator ~ "tptfd.txt";
        assertThat(tptfd.exists(), true);
        assertThat(stuff.exists(), false); //got renamed
        part.cleanUp();
        assertThat(tptfd.exists(), true);  //explicitly written file did not get removed after cleanup
        tptfd.deleteOnExit(); //clean up test
    }

    
    void testPartTmpFileDeletion() {
        MultipartConfig config = new MultipartConfig(_dirname, 1024, 3072, 50);
        MultipartFormInputStream mpis = new MultipartFormInputStream(
                new ByteArrayInputStream(cast(byte[])createMultipartRequestString("tptfd")),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        Part[] parts = mpis.getParts();

        MultipartFormInputStream.MultiPart part = cast(MultipartFormInputStream.MultiPart) mpis.getPart("stuff");
        string stuff = part.getFile();
        assert(!stuff.empty()); // longer than 100 bytes, should already be a tmp file
        assertThat(stuff.exists(), true);
        part.cleanUp();
        assertThat(stuff.exists(), false);  //tmp file was removed after cleanup
    }

    
    void testLFOnlyRequest() {
        string str = "--AaB03x\n" ~
                "content-disposition: form-data; name=\"field1\"\n" ~
                "\n" ~
                "Joe Blow" ~
                "\r\n--AaB03x\n" ~
                "content-disposition: form-data; name=\"field2\"\n" ~
                "\n" ~
                "Other" ~
                "\r\n--AaB03x--\n";

        MultipartConfig config = new MultipartConfig(_dirname, 1024, 3072, 50);
        MultipartFormInputStream mpis = new MultipartFormInputStream(new ByteArrayInputStream(cast(byte[])str),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        Part[] parts = mpis.getParts();
        assertThat(parts.length, 2);
        Part p1 = mpis.getPart("field1");
        assert(p1 !is null);
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        IOUtils.copy(p1.getInputStream(), baos);
        assertThat(baos.toString("UTF-8"), "Joe Blow");

        Part p2 = mpis.getPart("field2");
        assert(p2 !is null);
        baos = new ByteArrayOutputStream();
        IOUtils.copy(p2.getInputStream(), baos);
        assertThat(baos.toString("UTF-8"), "Other");
    }

    void testCROnlyRequest() {
        string str = "--AaB03x\r" ~
                "content-disposition: form-data; name=\"field1\"\r" ~
                "\r" ~
                "Joe Blow\r" ~
                "--AaB03x\r" ~
                "content-disposition: form-data; name=\"field2\"\r" ~
                "\r" ~
                "Other\r" ~
                "--AaB03x--\r";

        MultipartConfig config = new MultipartConfig(_dirname, 1024, 3072, 50);
        MultipartFormInputStream mpis = new MultipartFormInputStream(new ByteArrayInputStream(cast(byte[])str),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);

        try {
            Part[] parts = mpis.getParts();
            assertThat(parts.length, 2);

            assertThat(parts.length, 2);
            Part p1 = mpis.getPart("field1");
            assert(p1 !is null);

            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            IOUtils.copy(p1.getInputStream(), baos);
            assertThat(baos.toString("UTF-8"), "Joe Blow");

            Part p2 = mpis.getPart("field2");
            assert(p2 !is null);
            baos = new ByteArrayOutputStream();
            IOUtils.copy(p2.getInputStream(), baos);
            assertThat(baos.toString("UTF-8"), "Other");
        } catch (Throwable e) {
            warning(e.msg);
            assertTrue(e.msg.canFind("Bad EOL"));
        }
    }

    
    void testCRandLFMixRequest() {
        string str = "--AaB03x\r" ~
                "content-disposition: form-data; name=\"field1\"\r" ~
                "\r" ~
                "\nJoe Blow\n" ~
                "\r" ~
                "--AaB03x\r" ~
                "content-disposition: form-data; name=\"field2\"\r" ~
                "\r" ~
                "Other\r" ~
                "--AaB03x--\r";

        MultipartConfig config = new MultipartConfig(_dirname, 1024, 3072, 50);
        MultipartFormInputStream mpis = new MultipartFormInputStream(new ByteArrayInputStream(cast(byte[])str),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);


        try {
            Part[] parts = mpis.getParts();
            assertThat(parts.length, 2);

            Part p1 = mpis.getPart("field1");
            assert(p1 !is null);
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            IOUtils.copy(p1.getInputStream(), baos);
            assertThat(baos.toString("UTF-8"), "\nJoe Blow\n");

            Part p2 = mpis.getPart("field2");
            assert(p2 !is null);
            baos = new ByteArrayOutputStream();
            IOUtils.copy(p2.getInputStream(), baos);
            assertThat(baos.toString("UTF-8"), "Other");
        } catch (Throwable e) {
            assertTrue(e.msg.canFind("Bad EOL"));
        }
    }

    // FIXME: Needing refactor or cleanup -@zxp at 11/25/2018, 10:59:49 AM
    // 
    void testBufferOverflowNoCRLF() {
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        baos.write(cast(byte[])"--AaB03x\r\n");
        for (int i = 0; i < 3000; i++) { //create content that will overrun default buffer size of BufferedInputStream
            baos.write('a');
        }

        // _dirname = tempDir() ~ dirSeparator ~ "myfiles-" ~ DateTimeHelper.currentTimeMillis().to!string();
        // _tmpDir = this._dirname;

        MultipartConfig config = new MultipartConfig(_dirname, 1024, 3072, 50);
        MultipartFormInputStream mpis = new MultipartFormInputStream(new ByteArrayInputStream(baos.toByteArray()),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        try {
            mpis.getParts();
            Assert.fail("Header Line Exceeded Max Length");
        } catch (Throwable e) {
            assertTrue(e.msg.startsWith("Header Line Exceeded Max Length"));
        }
    }
    
    void testCharsetEncoding() {
        string contentType = "multipart/form-data; boundary=TheBoundary; charset=ISO-8859-1";
        string str = "--TheBoundary\r\n" ~
                "content-disposition: form-data; name=\"field1\"\r\n" ~
                "\r\n" ~
                "\nJoe Blow\n" ~
                "\r\n" ~
                "--TheBoundary--\r\n";

        MultipartConfig config = new MultipartConfig(_dirname, 1024, 3072, 50);
        MultipartFormInputStream mpis = new MultipartFormInputStream(new ByteArrayInputStream(cast(byte[])str),
                contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        Part[] parts = mpis.getParts();
        assertThat(parts.length, 1);
    }

    
    void testBadlyEncodedFilename() {
        string contents = "--AaB03x\r\n" ~
                "content-disposition: form-data; name=\"stuff\"; filename=\"" ~ "Taken on Aug 22 \\ 2012.jpg" ~ "\"\r\n" ~
                "Content-Type: text/plain\r\n" ~
                "\r\n" ~ "stuff" ~
                "aaa" ~ "\r\n" ~
                "--AaB03x--\r\n";

        MultipartConfig config = new MultipartConfig(_dirname, 1024, 3072, 50);
        MultipartFormInputStream mpis = new MultipartFormInputStream(new ByteArrayInputStream(cast(byte[])contents),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        Part[] parts = mpis.getParts();
        assertThat(parts.length, 1);
        assertThat(parts[0].getSubmittedFileName(), "Taken on Aug 22 \\ 2012.jpg");
    }

    void testBadlyEncodedMSFilename() {

        string contents = "--AaB03x\r\n" ~
                "content-disposition: form-data; name=\"stuff\"; filename=\"" ~ "c:\\this\\really\\is\\some\\path\\to\\a\\file.txt" ~ "\"\r\n" ~
                "Content-Type: text/plain\r\n" ~
                "\r\n" ~ "stuff" ~
                "aaa" ~ "\r\n" ~
                "--AaB03x--\r\n";

        MultipartConfig config = new MultipartConfig(_dirname, 1024, 3072, 50);
        MultipartFormInputStream mpis = new MultipartFormInputStream(new ByteArrayInputStream(cast(byte[])contents),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        Part[] parts = mpis.getParts();
        assertThat(parts.length, 1);
        assertThat(parts[0].getSubmittedFileName(), "c:\\this\\really\\is\\some\\path\\to\\a\\file.txt");
    }

    
    void testCorrectlyEncodedMSFilename() {
        string contents = "--AaB03x\r\n" ~
                "content-disposition: form-data; name=\"stuff\"; filename=\"" ~ "c:\\\\this\\\\really\\\\is\\\\some\\\\path\\\\to\\\\a\\\\file.txt" ~ "\"\r\n" ~
                "Content-Type: text/plain\r\n" ~
                "\r\n" ~ "stuff" ~
                "aaa" ~ "\r\n" ~
                "--AaB03x--\r\n";

        MultipartConfig config = new MultipartConfig(_dirname, 1024, 3072, 50);
        MultipartFormInputStream mpis = new MultipartFormInputStream(new ByteArrayInputStream(cast(byte[])contents),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        Part[] parts = mpis.getParts();
        assertThat(parts.length, 1);
        assertThat(parts[0].getSubmittedFileName(), "c:\\this\\really\\is\\some\\path\\to\\a\\file.txt");
    }

    void testMulti() {
        testMulti(FILENAME);
    }

    void testMultiWithSpaceInFilename() {
        testMulti("stuff with spaces.txt");
    }

    void testWriteFilesIfContentDispositionFilename() {
        string s = "--AaB03x\r\n" ~
                "content-disposition: form-data; name=\"field1\"; filename=\"frooble.txt\"\r\n" ~
                "\r\n" ~
                "Joe Blow\r\n" ~
                "--AaB03x\r\n" ~
                "content-disposition: form-data; name=\"stuff\"\r\n" ~
                "Content-Type: text/plain\r\n" ~
                "\r\n" ~ "sss" ~
                "aaa" ~ "\r\n" ~
                "--AaB03x--\r\n";
        //all default values for multipartconfig, ie file size threshold 0
        MultipartConfig config = new MultipartConfig(_dirname);
        MultipartFormInputStream mpis = new MultipartFormInputStream(new ByteArrayInputStream(cast(byte[])s),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        mpis.setWriteFilesWithFilenames(true);
        Part[] parts = mpis.getParts();
        assertThat(parts.length, 2);
        Part field1 = mpis.getPart("field1"); //has a filename, should be written to a file
        string f = (cast(MultipartFormInputStream.MultiPart) field1).getFile();
        assert(!f.empty()); // longer than 100 bytes, should already be a tmp file

        Part stuff = mpis.getPart("stuff");
        f = (cast(MultipartFormInputStream.MultiPart)stuff).getFile(); //should only be in memory, no filename
        assert(f.empty());
    }


    private void testMulti(string filename) {
        MultipartConfig config = new MultipartConfig(_dirname, 1024, 3072, 50);
        MultipartFormInputStream mpis = new MultipartFormInputStream(
                new ByteArrayInputStream(cast(byte[])createMultipartRequestString(filename)),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        Part[] parts = mpis.getParts();
        assertThat(parts.length, 2);
        Part field1 = mpis.getPart("field1");  //field 1 too small to go into tmp file, should be in internal buffer
        assert(field1 !is null);
        assertThat(field1.getName(), "field1");
        InputStream inputStream = field1.getInputStream();
        ByteArrayOutputStream os = new ByteArrayOutputStream();
        IOUtils.copy(inputStream, os);
        assertEquals("Joe Blow", cast(string)(os.toByteArray()));
        assertEquals(8, field1.getSize());

        assertNotNull((cast(MultipartFormInputStream.MultiPart) field1).getBytes());//in internal buffer
        field1.write("field1.txt");
        assertNull((cast(MultipartFormInputStream.MultiPart) field1).getBytes());//no longer in internal buffer
        string f = _dirname ~ dirSeparator ~ "field1.txt";
        assertTrue(f.exists());
        field1.write("another_field1.txt"); //write after having already written
        string f2 = _dirname ~ dirSeparator ~ "another_field1.txt";
        assertTrue(f2.exists());
        assertFalse(f.exists()); //should have been renamed
        field1.remove();  //file should be deleted
        assertFalse(f.exists()); //original file was renamed
        assertFalse(f2.exists()); //2nd written file was explicitly deleted

        MultipartFormInputStream.MultiPart stuff = cast(MultipartFormInputStream.MultiPart) mpis.getPart("stuff");
        assertThat(stuff.getSubmittedFileName(), filename);
        assertThat(stuff.getContentType(), "text/plain");
        assertThat(stuff.getHeader("Content-Type"), "text/plain");
        assertThat(stuff.getHeaders("content-type").size(), 1);
        assertThat(stuff.getHeader("content-disposition"), "form-data; name=\"stuff\"; filename=\"" ~ filename ~ "\"");
        assertThat(stuff.getHeaderNames().length, 2);
        assertThat(stuff.getSize(), 51L);

        string tmpfile = stuff.getFile();
        assert(!tmpfile.empty()); // longer than 50 bytes, should already be a tmp file
        assertThat(stuff.getBytes(), null); //not in an internal buffer
        assertThat(tmpfile.exists(), true);
        assert(tmpfile.baseName() != "stuff with space.txt");
        stuff.write(filename);
        f = _dirname ~ dirSeparator ~ filename;
        assertThat(f.exists(), true);
        assertThat(tmpfile.exists(), false);
        try {
            stuff.getInputStream();
        } catch (Exception e) {
            Assert.fail("Part.getInputStream() after file rename operation");
        }
        f.deleteOnExit(); //clean up after test
    }

    
    void testMultiSameNames() {
        string sameNames = "--AaB03x\r\n" ~
                "content-disposition: form-data; name=\"stuff\"; filename=\"stuff1.txt\"\r\n" ~
                "Content-Type: text/plain\r\n" ~
                "\r\n" ~
                "00000\r\n" ~
                "--AaB03x\r\n" ~
                "content-disposition: form-data; name=\"stuff\"; filename=\"stuff2.txt\"\r\n" ~
                "Content-Type: text/plain\r\n" ~
                "\r\n" ~
                "110000000000000000000000000000000000000000000000000\r\n" ~
                "--AaB03x--\r\n";

        MultipartConfig config = new MultipartConfig(_dirname, 1024, 3072, 50);
        MultipartFormInputStream mpis = new MultipartFormInputStream(new ByteArrayInputStream(cast(byte[])sameNames),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        Part[] parts = mpis.getParts();
        assertEquals(2, parts.length);
        foreach (Part p ; parts)
            assertEquals("stuff", p.getName());

        //if they all have the name name, then only retrieve the first one
        Part p = mpis.getPart("stuff");
        assertNotNull(p);
        assertEquals(5, p.getSize());
    }

    
    void testBase64EncodedContent() {
        string s = cast(string)Base64.encode(cast(ubyte[])"hello jetty");
        string contentWithEncodedPart =
                "--AaB03x\r\n" ~
                        "Content-disposition: form-data; name=\"other\"\r\n" ~
                        "Content-Type: text/plain\r\n" ~
                        "\r\n" ~
                        "other" ~ "\r\n" ~
                        "--AaB03x\r\n" ~
                        "Content-disposition: form-data; name=\"stuff\"; filename=\"stuff.txt\"\r\n" ~
                        "Content-Transfer-Encoding: base64\r\n" ~
                        "Content-Type: application/octet-stream\r\n" ~
                        "\r\n" ~
                        s ~ "\r\n" ~
                        "--AaB03x\r\n" ~
                        "Content-disposition: form-data; name=\"final\"\r\n" ~
                        "Content-Type: text/plain\r\n" ~
                        "\r\n" ~
                        "the end" ~ "\r\n" ~
                        "--AaB03x--\r\n";

        MultipartConfig config = new MultipartConfig(_dirname, 1024, 3072, 50);
        MultipartFormInputStream mpis = new MultipartFormInputStream(
                new ByteArrayInputStream(cast(byte[])contentWithEncodedPart),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        Part[] parts = mpis.getParts();
        assertEquals(3, parts.length);

        Part p1 = mpis.getPart("other");
        assertNotNull(p1);
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        IOUtils.copy(p1.getInputStream(), baos);
        assertEquals("other", baos.toString());

        Part p2 = mpis.getPart("stuff");
        assertNotNull(p2);
        baos = new ByteArrayOutputStream();
        IOUtils.copy(p2.getInputStream(), baos);
        assertEquals(Base64.encode(cast(ubyte[])"hello jetty"), baos.toString());

        Part p3 = mpis.getPart("final");
        assertNotNull(p3);
        baos = new ByteArrayOutputStream();
        IOUtils.copy(p3.getInputStream(), baos);
        assertEquals("the end", baos.toString());
    }
    
    void testQuotedPrintableEncoding() {
        string contentWithEncodedPart =
                "--AaB03x\r\n" ~
                        "Content-disposition: form-data; name=\"other\"\r\n" ~
                        "Content-Type: text/plain\r\n" ~
                        "\r\n" ~
                        "other" ~ "\r\n" ~
                        "--AaB03x\r\n" ~
                        "Content-disposition: form-data; name=\"stuff\"; filename=\"stuff.txt\"\r\n" ~
                        "Content-Transfer-Encoding: quoted-printable\r\n" ~
                        "Content-Type: text/plain\r\n" ~
                        "\r\n" ~
                        "truth=3Dbeauty" ~ "\r\n" ~
                        "--AaB03x--\r\n";
        MultipartConfig config = new MultipartConfig(_dirname, 1024, 3072, 50);
        MultipartFormInputStream mpis = new MultipartFormInputStream(new ByteArrayInputStream(cast(byte[])contentWithEncodedPart),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        Part[] parts = mpis.getParts();
        assertEquals(2, parts.length);

        Part p1 = mpis.getPart("other");
        assertNotNull(p1);
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        IOUtils.copy(p1.getInputStream(), baos);
        assertEquals("other", baos.toString());

        Part p2 = mpis.getPart("stuff");
        assertNotNull(p2);
        baos = new ByteArrayOutputStream();
        IOUtils.copy(p2.getInputStream(), baos);
        assertEquals("truth=3Dbeauty", baos.toString());
    }

    void testGeneratedForm() {
        string contentType = "multipart/form-data, boundary=WebKitFormBoundary7MA4YWf7OaKlSxkTrZu0gW";
        string bodyContent = "Content-Type: multipart/form-data; boundary=WebKitFormBoundary7MA4YWf7OaKlSxkTrZu0gW\r\n" ~
                "\r\n" ~
                "--WebKitFormBoundary7MA4YWf7OaKlSxkTrZu0gW\r\n" ~
                "Content-Disposition: form-data; name=\"part1\"\r\n" ~
                "\n" ~
                "wNfﾐxVam﾿t\r\n" ~
                "--WebKitFormBoundary7MA4YWf7OaKlSxkTrZu0gW\n" ~
                "Content-Disposition: form-data; name=\"part2\"\r\n" ~
                "\r\n" ~
                "&ﾳﾺ￙￹ￖￃO\r\n" ~
                "--WebKitFormBoundary7MA4YWf7OaKlSxkTrZu0gW--";


        MultipartConfig config = new MultipartConfig(_dirname, 1024, 3072, 50);
        MultipartFormInputStream mpis = new MultipartFormInputStream(new ByteArrayInputStream(cast(byte[])bodyContent),
                contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);

        Part[] parts = mpis.getParts();
        assert(parts.length>0);
        assertThat(parts.length, 2);

        Part part1 = mpis.getPart("part1");
        assert(part1 !is null);
        Part part2 = mpis.getPart("part2");
        assert(part2 !is null);
    }


    private string createMultipartRequestString(string filename) {
        size_t length = filename.length;
        string name = filename;
        if (length > 10)
            name = filename[0 .. 10];
        StringBuffer filler = new StringBuffer();
        size_t i = name.length;
        while (i < 51) {
            filler.append("0");
            i++;
        }

        return "--AaB03x\r\n" ~
                "content-disposition: form-data; name=\"field1\"; filename=\"frooble.txt\"\r\n" ~
                "\r\n" ~
                "Joe Blow\r\n" ~
                "--AaB03x\r\n" ~
                "content-disposition: form-data; name=\"stuff\"; filename=\"" ~ filename ~ "\"\r\n" ~
                "Content-Type: text/plain\r\n" ~
                "\r\n" ~ name ~
                filler.toString() ~ "\r\n" ~
                "--AaB03x--\r\n";
    }
}
