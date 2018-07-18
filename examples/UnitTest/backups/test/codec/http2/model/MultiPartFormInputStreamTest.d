module test.codec.http2.model;

import hunt.http.codec.http.model.MultiPartFormInputStream;
import hunt.http.utils.codec.B64Code;
import hunt.util.io;
import hunt.util.Test;

import javax.servlet.MultipartConfigElement;
import javax.servlet.ReadListener;
import javax.servlet.ServletException;
import javax.servlet.ServletInputStream;
import javax.servlet.http.Part;
import java.io;
import java.util.Collection;
import java.util.concurrent.TimeUnit;


import hunt.util.Assert;

/**
 * MultiPartInputStreamTest
 */
public class MultiPartFormInputStreamTest {
    private static final string FILENAME = "stuff.txt";
    protected string _contentType = "multipart/form-data, boundary=AaB03x";
    protected string _multi = createMultipartRequestString(FILENAME);
    protected string _dirname = System.getProperty("java.io.tmpdir") + File.separator ~ "myfiles-" ~ TimeUnit.NANOSECONDS.toMillis(System.nanoTime());
    protected File _tmpDir = new File(_dirname);

    public MultiPartFormInputStreamTest() {
        _tmpDir.deleteOnExit();
    }

    
    public void testBadMultiPartRequest()
            {
        string boundary = "X0Y0";
        string str = "--" ~ boundary ~ "\r\n" ~
                "Content-Disposition: form-data; name=\"fileup\"; filename=\"test.upload\"\r\n" ~
                "Content-Type: application/octet-stream\r\n\r\n" ~
                "How now brown cow." ~
                "\r\n--" ~ boundary ~ "-\r\n"
                ~ "Content-Disposition: form-data; name=\"fileup\"; filename=\"test.upload\"\r\n"
                ~ "\r\n";

        MultipartConfigElement config = new MultipartConfigElement(_dirname, 1024, 3072, 50);
        MultiPartFormInputStream mpis = new MultiPartFormInputStream(new ByteArrayInputStream(str.getBytes()),
                "multipart/form-data, boundary=" ~ boundary,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        try {
            mpis.getParts();
            fail("Incomplete Multipart");
        } catch (IOException e) {
            assertTrue(e.getMessage().startsWith("Incomplete"));
        }
    }


    
    public void testFinalBoundaryOnly()
            {
        string delimiter = "\r\n";
        final string boundary = "MockMultiPartTestBoundary";


        // Malformed multipart request body containing only an arbitrary string of text, followed by the final boundary marker, delimited by empty lines.
        string str =
                delimiter +
                        "Hello world" ~
                        delimiter +        // Two delimiter markers, which make an empty line.
                        delimiter +
                        "--" ~ boundary ~ "--" ~ delimiter;

        MultipartConfigElement config = new MultipartConfigElement(_dirname, 1024, 3072, 50);
        MultiPartFormInputStream mpis = new MultiPartFormInputStream(new ByteArrayInputStream(str.getBytes()),
                "multipart/form-data, boundary=" ~ boundary,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        Collection<Part> parts = mpis.getParts();
        assertTrue(mpis.getParts().isEmpty());
    }


    
    public void testEmpty()
            {
        string delimiter = "\r\n";
        final string boundary = "MockMultiPartTestBoundary";

        string str =
                delimiter +
                        "--" ~ boundary ~ "--" ~ delimiter;

        MultipartConfigElement config = new MultipartConfigElement(_dirname, 1024, 3072, 50);
        MultiPartFormInputStream mpis = new MultiPartFormInputStream(new ByteArrayInputStream(str.getBytes()),
                "multipart/form-data, boundary=" ~ boundary,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        assertTrue(mpis.getParts().isEmpty());
    }

    
    public void testNoBoundaryRequest()
            {
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

        MultipartConfigElement config = new MultipartConfigElement(_dirname, 1024, 3072, 50);
        MultiPartFormInputStream mpis = new MultiPartFormInputStream(new ByteArrayInputStream(str.getBytes()),
                "multipart/form-data",
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        Collection<Part> parts = mpis.getParts();
        assertThat(parts.size(), is(4));

        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        Part fileName = mpis.getPart("fileName");
        assertThat(fileName, notNullValue());
        assertThat(fileName.getSize(), is(3L));
        IO.copy(fileName.getInputStream(), baos);
        assertThat(baos.toString("US-ASCII"), is("abc"));

        baos = new ByteArrayOutputStream();
        Part desc = mpis.getPart("desc");
        assertThat(desc, notNullValue());
        assertThat(desc.getSize(), is(3L));
        IO.copy(desc.getInputStream(), baos);
        assertThat(baos.toString("US-ASCII"), is("123"));

        baos = new ByteArrayOutputStream();
        Part title = mpis.getPart("title");
        assertThat(title, notNullValue());
        assertThat(title.getSize(), is(3L));
        IO.copy(title.getInputStream(), baos);
        assertThat(baos.toString("US-ASCII"), is("ttt"));
    }

    
    public void testNonMultiPartRequest()
            {
        MultipartConfigElement config = new MultipartConfigElement(_dirname, 1024, 3072, 50);
        MultiPartFormInputStream mpis = new MultiPartFormInputStream(new ByteArrayInputStream(_multi.getBytes()),
                "Content-type: text/plain",
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        assertTrue(mpis.getParts().isEmpty());
    }

    
    public void testNoBody()
            {
        string body = "";

        MultipartConfigElement config = new MultipartConfigElement(_dirname, 1024, 3072, 50);
        MultiPartFormInputStream mpis = new MultiPartFormInputStream(new ByteArrayInputStream(body.getBytes()),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        try {
            mpis.getParts();
            fail("Missing initial multi part boundary");
        } catch (IOException e) {
            assertTrue(e.getMessage().contains("Missing initial multi part boundary"));
        }
    }


    
    public void testBodyAlreadyConsumed()
            {
        ServletInputStream is = new ServletInputStream() {

            override
            public bool isFinished() {
                return true;
            }

            override
            public bool isReady() {
                return false;
            }

            override
            public void setReadListener(ReadListener readListener) {
            }

            override
            public int read() throws IOException {
                return 0;
            }

        };

        MultipartConfigElement config = new MultipartConfigElement(_dirname, 1024, 3072, 50);
        MultiPartFormInputStream mpis = new MultiPartFormInputStream(is,
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        Collection<Part> parts = mpis.getParts();
        assertEquals(0, parts.size());
    }


    
    public void testWhitespaceBodyWithCRLF()
            {
        string whitespace = "              \n\n\n\r\n\r\n\r\n\r\n";


        MultipartConfigElement config = new MultipartConfigElement(_dirname, 1024, 3072, 50);
        MultiPartFormInputStream mpis = new MultiPartFormInputStream(new ByteArrayInputStream(whitespace.getBytes()),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        try {
            mpis.getParts();
            fail("Missing initial multi part boundary");
        } catch (IOException e) {
            assertTrue(e.getMessage().contains("Missing initial multi part boundary"));
        }
    }

    
    public void testWhitespaceBody()
            {
        string whitespace = " ";

        MultipartConfigElement config = new MultipartConfigElement(_dirname, 1024, 3072, 50);
        MultiPartFormInputStream mpis = new MultiPartFormInputStream(new ByteArrayInputStream(whitespace.getBytes()),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        try {
            mpis.getParts();
            fail("Multipart missing body");
        } catch (IOException e) {
            assertTrue(e.getMessage().startsWith("Missing initial"));
        }
    }

    
    public void testLeadingWhitespaceBodyWithCRLF()
            {
        string body = "              \n\n\n\r\n\r\n\r\n\r\n" ~
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


        MultipartConfigElement config = new MultipartConfigElement(_dirname, 1024, 3072, 50);
        MultiPartFormInputStream mpis = new MultiPartFormInputStream(new ByteArrayInputStream(body.getBytes()),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);

        Collection<Part> parts = mpis.getParts();
        assertThat(parts, notNullValue());
        assertThat(parts.size(), is(2));
        Part field1 = mpis.getPart("field1");
        assertThat(field1, notNullValue());
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        IO.copy(field1.getInputStream(), baos);
        assertThat(baos.toString("US-ASCII"), is("Joe Blow"));

        Part stuff = mpis.getPart("stuff");
        assertThat(stuff, notNullValue());
        baos = new ByteArrayOutputStream();
        IO.copy(stuff.getInputStream(), baos);
        assertTrue(baos.toString("US-ASCII").contains("aaaa"));
    }


    
    public void testLeadingWhitespaceBodyWithoutCRLF()
            {
        string body = "            " ~
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

        MultipartConfigElement config = new MultipartConfigElement(_dirname, 1024, 3072, 50);
        MultiPartFormInputStream mpis = new MultiPartFormInputStream(new ByteArrayInputStream(body.getBytes()),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);

        Collection<Part> parts = mpis.getParts();
        assertThat(parts, notNullValue());
        assertThat(parts.size(), is(1));

        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        Part stuff = mpis.getPart("stuff");
        assertThat(stuff, notNullValue());
        baos = new ByteArrayOutputStream();
        IO.copy(stuff.getInputStream(), baos);
        assertTrue(baos.toString("US-ASCII").contains("bbbbb"));
    }


    
    public void testNoLimits()
            {
        MultipartConfigElement config = new MultipartConfigElement(_dirname);
        MultiPartFormInputStream mpis = new MultiPartFormInputStream(new ByteArrayInputStream(_multi.getBytes()),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        Collection<Part> parts = mpis.getParts();
        assertFalse(parts.isEmpty());
    }

    
    public void testRequestTooBig()
            {
        MultipartConfigElement config = new MultipartConfigElement(_dirname, 60, 100, 50);
        MultiPartFormInputStream mpis = new MultiPartFormInputStream(new ByteArrayInputStream(_multi.getBytes()),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);

        try {
            mpis.getParts();
            fail("Request should have exceeded maxRequestSize");
        } catch (IllegalStateException e) {
            assertTrue(e.getMessage().startsWith("Request exceeds maxRequestSize"));
        }
    }


    
    public void testRequestTooBigThrowsErrorOnGetParts()
            {
        MultipartConfigElement config = new MultipartConfigElement(_dirname, 60, 100, 50);
        MultiPartFormInputStream mpis = new MultiPartFormInputStream(new ByteArrayInputStream(_multi.getBytes()),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        Collection<Part> parts = null;

        //cause parsing
        try {
            parts = mpis.getParts();
            fail("Request should have exceeded maxRequestSize");
        } catch (IllegalStateException e) {
            assertTrue(e.getMessage().startsWith("Request exceeds maxRequestSize"));
        }

        //try again
        try {
            parts = mpis.getParts();
            fail("Request should have exceeded maxRequestSize");
        } catch (IllegalStateException e) {
            assertTrue(e.getMessage().startsWith("Request exceeds maxRequestSize"));
        }
    }

    
    public void testFileTooBig()
            {
        MultipartConfigElement config = new MultipartConfigElement(_dirname, 40, 1024, 30);
        MultiPartFormInputStream mpis = new MultiPartFormInputStream(new ByteArrayInputStream(_multi.getBytes()),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        Collection<Part> parts = null;
        try {
            parts = mpis.getParts();
            fail("stuff.txt should have been larger than maxFileSize");
        } catch (IllegalStateException e) {
            assertTrue(e.getMessage().startsWith("Multipart Mime part"));
        }
    }

    
    public void testFileTooBigThrowsErrorOnGetParts()
            {
        MultipartConfigElement config = new MultipartConfigElement(_dirname, 40, 1024, 30);
        MultiPartFormInputStream mpis = new MultiPartFormInputStream(new ByteArrayInputStream(_multi.getBytes()),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        Collection<Part> parts = null;
        try {
            parts = mpis.getParts(); //caused parsing
            fail("stuff.txt should have been larger than maxFileSize");
        } catch (Throwable e) {
            assertTrue(e.getMessage().startsWith("Multipart Mime part"));
        }

        //test again after the parsing
        try {
            parts = mpis.getParts(); //caused parsing
            fail("stuff.txt should have been larger than maxFileSize");
        } catch (IllegalStateException e) {
            assertTrue(e.getMessage().startsWith("Multipart Mime part"));
        }
    }


    
    public void testPartFileNotDeleted() {
        MultipartConfigElement config = new MultipartConfigElement(_dirname, 1024, 3072, 50);
        MultiPartFormInputStream mpis = new MultiPartFormInputStream(new ByteArrayInputStream(createMultipartRequestString("tptfd").getBytes()),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        Collection<Part> parts = mpis.getParts();

        MultiPartFormInputStream.MultiPart part = (MultiPartFormInputStream.MultiPart) mpis.getPart("stuff");
        File stuff = ((MultiPartFormInputStream.MultiPart) part).getFile();
        assertThat(stuff, notNullValue()); // longer than 100 bytes, should already be a tmp file
        part.write("tptfd.txt");
        File tptfd = new File(_dirname + File.separator ~ "tptfd.txt");
        assertThat(tptfd.exists(), is(true));
        assertThat(stuff.exists(), is(false)); //got renamed
        part.cleanUp();
        assertThat(tptfd.exists(), is(true));  //explicitly written file did not get removed after cleanup
        tptfd.deleteOnExit(); //clean up test
    }

    
    public void testPartTmpFileDeletion() {
        MultipartConfigElement config = new MultipartConfigElement(_dirname, 1024, 3072, 50);
        MultiPartFormInputStream mpis = new MultiPartFormInputStream(new ByteArrayInputStream(createMultipartRequestString("tptfd").getBytes()),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        Collection<Part> parts = mpis.getParts();

        MultiPartFormInputStream.MultiPart part = (MultiPartFormInputStream.MultiPart) mpis.getPart("stuff");
        File stuff = ((MultiPartFormInputStream.MultiPart) part).getFile();
        assertThat(stuff, notNullValue()); // longer than 100 bytes, should already be a tmp file
        assertThat(stuff.exists(), is(true));
        part.cleanUp();
        assertThat(stuff.exists(), is(false));  //tmp file was removed after cleanup
    }

    
    public void testLFOnlyRequest()
            {
        string str = "--AaB03x\n" ~
                "content-disposition: form-data; name=\"field1\"\n" ~
                "\n" ~
                "Joe Blow" ~
                "\r\n--AaB03x\n" ~
                "content-disposition: form-data; name=\"field2\"\n" ~
                "\n" ~
                "Other" ~
                "\r\n--AaB03x--\n";

        MultipartConfigElement config = new MultipartConfigElement(_dirname, 1024, 3072, 50);
        MultiPartFormInputStream mpis = new MultiPartFormInputStream(new ByteArrayInputStream(str.getBytes()),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        Collection<Part> parts = mpis.getParts();
        assertThat(parts.size(), is(2));
        Part p1 = mpis.getPart("field1");
        assertThat(p1, notNullValue());
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        IO.copy(p1.getInputStream(), baos);
        assertThat(baos.toString("UTF-8"), is("Joe Blow"));

        Part p2 = mpis.getPart("field2");
        assertThat(p2, notNullValue());
        baos = new ByteArrayOutputStream();
        IO.copy(p2.getInputStream(), baos);
        assertThat(baos.toString("UTF-8"), is("Other"));


    }

    
    public void testCROnlyRequest()
            {
        string str = "--AaB03x\r" ~
                "content-disposition: form-data; name=\"field1\"\r" ~
                "\r" ~
                "Joe Blow\r" ~
                "--AaB03x\r" ~
                "content-disposition: form-data; name=\"field2\"\r" ~
                "\r" ~
                "Other\r" ~
                "--AaB03x--\r";

        MultipartConfigElement config = new MultipartConfigElement(_dirname, 1024, 3072, 50);
        MultiPartFormInputStream mpis = new MultiPartFormInputStream(new ByteArrayInputStream(str.getBytes()),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);

        try {
            Collection<Part> parts = mpis.getParts();
            assertThat(parts.size(), is(2));

            assertThat(parts.size(), is(2));
            Part p1 = mpis.getPart("field1");
            assertThat(p1, notNullValue());

            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            IO.copy(p1.getInputStream(), baos);
            assertThat(baos.toString("UTF-8"), is("Joe Blow"));

            Part p2 = mpis.getPart("field2");
            assertThat(p2, notNullValue());
            baos = new ByteArrayOutputStream();
            IO.copy(p2.getInputStream(), baos);
            assertThat(baos.toString("UTF-8"), is("Other"));
        } catch (Throwable e) {
            assertTrue(e.getMessage().contains("Bad EOL"));
        }
    }

    
    public void testCRandLFMixRequest()
            {
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

        MultipartConfigElement config = new MultipartConfigElement(_dirname, 1024, 3072, 50);
        MultiPartFormInputStream mpis = new MultiPartFormInputStream(new ByteArrayInputStream(str.getBytes()),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);


        try {
            Collection<Part> parts = mpis.getParts();
            assertThat(parts.size(), is(2));

            Part p1 = mpis.getPart("field1");
            assertThat(p1, notNullValue());
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            IO.copy(p1.getInputStream(), baos);
            assertThat(baos.toString("UTF-8"), is("\nJoe Blow\n"));

            Part p2 = mpis.getPart("field2");
            assertThat(p2, notNullValue());
            baos = new ByteArrayOutputStream();
            IO.copy(p2.getInputStream(), baos);
            assertThat(baos.toString("UTF-8"), is("Other"));
        } catch (Throwable e) {
            assertTrue(e.getMessage().contains("Bad EOL"));
        }
    }

    
    public void testBufferOverflowNoCRLF() {
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        baos.write("--AaB03x\r\n".getBytes());
        for (int i = 0; i < 3000; i++) //create content that will overrun default buffer size of BufferedInputStream
        {
            baos.write('a');
        }

        MultipartConfigElement config = new MultipartConfigElement(_dirname, 1024, 3072, 50);
        MultiPartFormInputStream mpis = new MultiPartFormInputStream(new ByteArrayInputStream(baos.toByteArray()),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        try {
            mpis.getParts();
            fail("Header Line Exceeded Max Length");
        } catch (Throwable e) {
            assertTrue(e.getMessage().startsWith("Header Line Exceeded Max Length"));
        }

    }

    
    public void testCharsetEncoding() {
        string contentType = "multipart/form-data; boundary=TheBoundary; charset=ISO-8859-1";
        string str = "--TheBoundary\r\n" ~
                "content-disposition: form-data; name=\"field1\"\r\n" ~
                "\r\n" ~
                "\nJoe Blow\n" ~
                "\r\n" ~
                "--TheBoundary--\r\n";

        MultipartConfigElement config = new MultipartConfigElement(_dirname, 1024, 3072, 50);
        MultiPartFormInputStream mpis = new MultiPartFormInputStream(new ByteArrayInputStream(str.getBytes()),
                contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        Collection<Part> parts = mpis.getParts();
        assertThat(parts.size(), is(1));
    }


    
    public void testBadlyEncodedFilename() {

        string contents = "--AaB03x\r\n" ~
                "content-disposition: form-data; name=\"stuff\"; filename=\"" ~ "Taken on Aug 22 \\ 2012.jpg" ~ "\"\r\n" ~
                "Content-Type: text/plain\r\n" ~
                "\r\n" ~ "stuff" ~
                "aaa" ~ "\r\n" ~
                "--AaB03x--\r\n";

        MultipartConfigElement config = new MultipartConfigElement(_dirname, 1024, 3072, 50);
        MultiPartFormInputStream mpis = new MultiPartFormInputStream(new ByteArrayInputStream(contents.getBytes()),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        Collection<Part> parts = mpis.getParts();
        assertThat(parts.size(), is(1));
        assertThat(((MultiPartFormInputStream.MultiPart) parts.iterator().next()).getSubmittedFileName(), is("Taken on Aug 22 \\ 2012.jpg"));
    }

    
    public void testBadlyEncodedMSFilename() {

        string contents = "--AaB03x\r\n" ~
                "content-disposition: form-data; name=\"stuff\"; filename=\"" ~ "c:\\this\\really\\is\\some\\path\\to\\a\\file.txt" ~ "\"\r\n" ~
                "Content-Type: text/plain\r\n" ~
                "\r\n" ~ "stuff" ~
                "aaa" ~ "\r\n" ~
                "--AaB03x--\r\n";

        MultipartConfigElement config = new MultipartConfigElement(_dirname, 1024, 3072, 50);
        MultiPartFormInputStream mpis = new MultiPartFormInputStream(new ByteArrayInputStream(contents.getBytes()),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        Collection<Part> parts = mpis.getParts();
        assertThat(parts.size(), is(1));
        assertThat(((MultiPartFormInputStream.MultiPart) parts.iterator().next()).getSubmittedFileName(), is("c:\\this\\really\\is\\some\\path\\to\\a\\file.txt"));
    }

    
    public void testCorrectlyEncodedMSFilename() {
        string contents = "--AaB03x\r\n" ~
                "content-disposition: form-data; name=\"stuff\"; filename=\"" ~ "c:\\\\this\\\\really\\\\is\\\\some\\\\path\\\\to\\\\a\\\\file.txt" ~ "\"\r\n" ~
                "Content-Type: text/plain\r\n" ~
                "\r\n" ~ "stuff" ~
                "aaa" ~ "\r\n" ~
                "--AaB03x--\r\n";

        MultipartConfigElement config = new MultipartConfigElement(_dirname, 1024, 3072, 50);
        MultiPartFormInputStream mpis = new MultiPartFormInputStream(new ByteArrayInputStream(contents.getBytes()),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        Collection<Part> parts = mpis.getParts();
        assertThat(parts.size(), is(1));
        assertThat(((MultiPartFormInputStream.MultiPart) parts.iterator().next()).getSubmittedFileName(), is("c:\\this\\really\\is\\some\\path\\to\\a\\file.txt"));
    }

    public void testMulti()
            {
        testMulti(FILENAME);
    }

    
    public void testMultiWithSpaceInFilename() {
        testMulti("stuff with spaces.txt");
    }


    
    public void testWriteFilesIfContentDispositionFilename()
            {
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
        MultipartConfigElement config = new MultipartConfigElement(_dirname);
        MultiPartFormInputStream mpis = new MultiPartFormInputStream(new ByteArrayInputStream(s.getBytes()),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        mpis.setWriteFilesWithFilenames(true);
        Collection<Part> parts = mpis.getParts();
        assertThat(parts.size(), is(2));
        Part field1 = mpis.getPart("field1"); //has a filename, should be written to a file
        File f = ((MultiPartFormInputStream.MultiPart) field1).getFile();
        assertThat(f, notNullValue()); // longer than 100 bytes, should already be a tmp file

        Part stuff = mpis.getPart("stuff");
        f = ((MultiPartFormInputStream.MultiPart) stuff).getFile(); //should only be in memory, no filename
        assertThat(f, nullValue());
    }


    private void testMulti(string filename) throws IOException, ServletException, InterruptedException {
        MultipartConfigElement config = new MultipartConfigElement(_dirname, 1024, 3072, 50);
        MultiPartFormInputStream mpis = new MultiPartFormInputStream(new ByteArrayInputStream(createMultipartRequestString(filename).getBytes()),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        Collection<Part> parts = mpis.getParts();
        assertThat(parts.size(), is(2));
        Part field1 = mpis.getPart("field1");  //field 1 too small to go into tmp file, should be in internal buffer
        assertThat(field1, notNullValue());
        assertThat(field1.getName(), is("field1"));
        InputStream is = field1.getInputStream();
        ByteArrayOutputStream os = new ByteArrayOutputStream();
        IO.copy(is, os);
        assertEquals("Joe Blow", new string(os.toByteArray()));
        assertEquals(8, field1.getSize());

        assertNotNull(((MultiPartFormInputStream.MultiPart) field1).getBytes());//in internal buffer
        field1.write("field1.txt");
        assertNull(((MultiPartFormInputStream.MultiPart) field1).getBytes());//no longer in internal buffer
        File f = new File(_dirname + File.separator ~ "field1.txt");
        assertTrue(f.exists());
        field1.write("another_field1.txt"); //write after having already written
        File f2 = new File(_dirname + File.separator ~ "another_field1.txt");
        assertTrue(f2.exists());
        assertFalse(f.exists()); //should have been renamed
        field1.delete();  //file should be deleted
        assertFalse(f.exists()); //original file was renamed
        assertFalse(f2.exists()); //2nd written file was explicitly deleted

        MultiPartFormInputStream.MultiPart stuff = (MultiPartFormInputStream.MultiPart) mpis.getPart("stuff");
        assertThat(stuff.getSubmittedFileName(), is(filename));
        assertThat(stuff.getContentType(), is("text/plain"));
        assertThat(stuff.getHeader("Content-Type"), is("text/plain"));
        assertThat(stuff.getHeaders("content-type").size(), is(1));
        assertThat(stuff.getHeader("content-disposition"), is("form-data; name=\"stuff\"; filename=\"" ~ filename ~ "\""));
        assertThat(stuff.getHeaderNames().size(), is(2));
        assertThat(stuff.getSize(), is(51L));

        File tmpfile = ((MultiPartFormInputStream.MultiPart) stuff).getFile();
        assertThat(tmpfile, notNullValue()); // longer than 50 bytes, should already be a tmp file
        assertThat(stuff.getBytes(), nullValue()); //not in an internal buffer
        assertThat(tmpfile.exists(), is(true));
        assertThat(tmpfile.getName(), is(not("stuff with space.txt")));
        stuff.write(filename);
        f = new File(_dirname + File.separator + filename);
        assertThat(f.exists(), is(true));
        assertThat(tmpfile.exists(), is(false));
        try {
            stuff.getInputStream();
        } catch (Exception e) {
            fail("Part.getInputStream() after file rename operation");
        }
        f.deleteOnExit(); //clean up after test
    }

    
    public void testMultiSameNames()
            {
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

        MultipartConfigElement config = new MultipartConfigElement(_dirname, 1024, 3072, 50);
        MultiPartFormInputStream mpis = new MultiPartFormInputStream(new ByteArrayInputStream(sameNames.getBytes()),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        Collection<Part> parts = mpis.getParts();
        assertEquals(2, parts.size());
        for (Part p : parts)
            assertEquals("stuff", p.getName());

        //if they all have the name name, then only retrieve the first one
        Part p = mpis.getPart("stuff");
        assertNotNull(p);
        assertEquals(5, p.getSize());
    }

    
    public void testBase64EncodedContent() {
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
                        B64Code.encode("hello jetty") ~ "\r\n" ~
                        "--AaB03x\r\n" ~
                        "Content-disposition: form-data; name=\"final\"\r\n" ~
                        "Content-Type: text/plain\r\n" ~
                        "\r\n" ~
                        "the end" ~ "\r\n" ~
                        "--AaB03x--\r\n";

        MultipartConfigElement config = new MultipartConfigElement(_dirname, 1024, 3072, 50);
        MultiPartFormInputStream mpis = new MultiPartFormInputStream(new ByteArrayInputStream(contentWithEncodedPart.getBytes()),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        Collection<Part> parts = mpis.getParts();
        assertEquals(3, parts.size());

        Part p1 = mpis.getPart("other");
        assertNotNull(p1);
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        IO.copy(p1.getInputStream(), baos);
        assertEquals("other", baos.toString("US-ASCII"));

        Part p2 = mpis.getPart("stuff");
        assertNotNull(p2);
        baos = new ByteArrayOutputStream();
        IO.copy(p2.getInputStream(), baos);
        assertEquals(B64Code.encode("hello jetty"), baos.toString("US-ASCII"));

        Part p3 = mpis.getPart("final");
        assertNotNull(p3);
        baos = new ByteArrayOutputStream();
        IO.copy(p3.getInputStream(), baos);
        assertEquals("the end", baos.toString("US-ASCII"));
    }

    
    public void testQuotedPrintableEncoding() {
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
        MultipartConfigElement config = new MultipartConfigElement(_dirname, 1024, 3072, 50);
        MultiPartFormInputStream mpis = new MultiPartFormInputStream(new ByteArrayInputStream(contentWithEncodedPart.getBytes()),
                _contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);
        Collection<Part> parts = mpis.getParts();
        assertEquals(2, parts.size());

        Part p1 = mpis.getPart("other");
        assertNotNull(p1);
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        IO.copy(p1.getInputStream(), baos);
        assertEquals("other", baos.toString("US-ASCII"));

        Part p2 = mpis.getPart("stuff");
        assertNotNull(p2);
        baos = new ByteArrayOutputStream();
        IO.copy(p2.getInputStream(), baos);
        assertEquals("truth=3Dbeauty", baos.toString("US-ASCII"));
    }


    
    public void testGeneratedForm()
            {
        string contentType = "multipart/form-data, boundary=WebKitFormBoundary7MA4YWf7OaKlSxkTrZu0gW";
        string body = "Content-Type: multipart/form-data; boundary=WebKitFormBoundary7MA4YWf7OaKlSxkTrZu0gW\r\n" ~
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


        MultipartConfigElement config = new MultipartConfigElement(_dirname, 1024, 3072, 50);
        MultiPartFormInputStream mpis = new MultiPartFormInputStream(new ByteArrayInputStream(body.getBytes()),
                contentType,
                config,
                _tmpDir);
        mpis.setDeleteOnExit(true);

        Collection<Part> parts = mpis.getParts();
        assertThat(parts, notNullValue());
        assertThat(parts.size(), is(2));

        Part part1 = mpis.getPart("part1");
        assertThat(part1, notNullValue());
        Part part2 = mpis.getPart("part2");
        assertThat(part2, notNullValue());
    }


    private string createMultipartRequestString(string filename) {
        int length = filename.length;
        string name = filename;
        if (length > 10)
            name = filename.substring(0, 10);
        StringBuffer filler = new StringBuffer();
        int i = name.length;
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
                "\r\n" ~ name +
                filler.toString() ~ "\r\n" ~
                "--AaB03x--\r\n";
    }
}
