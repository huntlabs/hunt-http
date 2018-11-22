module hunt.http.codec.http.model.MultiPartFormInputStream;

/++
// import hunt.http.utils.collection.LazyList;
// import hunt.http.utils.collection.MultiMap;
// import hunt.container.BufferUtils;
// import hunt.http.utils.io.ByteArrayOutputStream;
// import hunt.http.utils.lang.QuotedStringTokenizer;
import hunt.io;
import hunt.logging;
import hunt.string;


// import javax.servlet.MultipartConfigElement;
// import javax.servlet.ServletInputStream;
// import javax.servlet.http.Part;
// import java.io;
// import hunt.container.ByteBuffer;
// import java.nio.file.Files;
// import java.nio.file.Path;
// import java.nio.file.StandardCopyOption;
// import java.util.ArrayList;
// import hunt.container.Collection;
// import hunt.container.Collections;
import hunt.container;

import std.file;
import std.string;

/**
 * MultiPartInputStream
 * <p>
 * Handle a MultiPart Mime input stream, breaking it up on the boundary into files and strings.
 *
 * @see <a href="https://tools.ietf.org/html/rfc7578">https://tools.ietf.org/html/rfc7578</a>
 */
class MultiPartFormInputStream {
    
    private int _bufferSize = 16 * 1024;
    // static MultipartConfigElement __DEFAULT_MULTIPART_CONFIG = new MultipartConfigElement(System.getProperty("java.io.tmpdir"));
    __gshared MultiMap!(Part) EMPTY_MAP;
    protected InputStream _in;
    protected MultipartConfigElement _config;
    protected string _contentType;
    protected MultiMap!(Part) _parts;
    protected Exception _err;
    protected File _tmpDir;
    protected File _contextTmpDir;
    protected bool _deleteOnExit;
    protected bool _writeFilesWithFilenames;
    protected bool _parsed;

    shared static this() {
        EMPTY_MAP = new MultiMap!(Part)(Collections!(Part).emptyMap());
    }

    class MultiPart : Part {
        protected string _name;
        protected string _filename;
        protected File _file;
        protected OutputStream _out;
        protected ByteArrayOutputStream _bout;
        protected string _contentType;
        protected MultiMap!string _headers;
        protected long _size = 0;
        protected bool _temporary = true;

        this(string name, string filename) {
            _name = name;
            _filename = filename;
        }

        override
        string toString() {
            return format("Part{n=%s,fn=%s,ct=%s,s=%d,tmp=%b,file=%s}", 
                _name, _filename, _contentType, _size, _temporary, _file);
        }

        protected void setContentType(string contentType) {
            _contentType = contentType;
        }

        protected void open() {
            // We will either be writing to a file, if it has a filename on the content-disposition
            // and otherwise a byte-array-input-stream, OR if we exceed the getFileSizeThreshold, we
            // will need to change to write to a file.
            if (isWriteFilesWithFilenames() && _filename != null && _filename.strip().length() > 0) {
                createFile();
            } else {
                // Write to a buffer in memory until we discover we've exceed the
                // MultipartConfig fileSizeThreshold
                _out = _bout = new ByteArrayOutputStream();
            }
        }

        protected void close() {
            _out.close();
        }

        protected void write(int b) {
            if (this.outer._config.getMaxFileSize() > 0 && _size + 1 > this.outer._config.getMaxFileSize())
                throw new IllegalStateException("Multipart Mime part " + _name + " exceeds max filesize");

            if (this.outer._config.getFileSizeThreshold() > 0 && _size + 1 > this.outer._config.getFileSizeThreshold()
                    && _file == null)
                createFile();

            _out.write(b);
            _size++;
        }

        protected void write(byte[] bytes, int offset, int length) {
            if (this.outer._config.getMaxFileSize() > 0 && _size + length > this.outer._config.getMaxFileSize())
                throw new IllegalStateException("Multipart Mime part " + _name + " exceeds max filesize");

            if (this.outer._config.getFileSizeThreshold() > 0
                    && _size + length > this.outer._config.getFileSizeThreshold() && _file == null)
                createFile();

            _out.write(bytes, offset, length);
            _size += length;
        }

        protected void createFile() {
            /*
             * Some statics just to make the code below easier to understand This get optimized away during the compile anyway
             */
            bool USER = true;
            bool WORLD = false;

            _file = File.createTempFile("MultiPart", "", this.outer._tmpDir);
            _file.setReadable(false, WORLD); // (reset) disable it for everyone first
            _file.setReadable(true, USER); // enable for user only

            if (_deleteOnExit)
                _file.deleteOnExit();
            FileOutputStream fos = new FileOutputStream(_file);
            BufferedOutputStream bos = new BufferedOutputStream(fos);

            if (_size > 0 && _out != null) {
                // already written some bytes, so need to copy them into the file
                _out.flush();
                _bout.writeTo(bos);
                _out.close();
            }
            _bout = null;
            _out = bos;
        }

        protected void setHeaders(MultiMap!string headers) {
            _headers = headers;
        }

        /**
         * @see Part#getContentType()
         */
        override
        string getContentType() {
            return _contentType;
        }

        /**
         * @see Part#getHeader(string)
         */
        override
        string getHeader(string name) {
            if (name == null)
                return null;
            return _headers.getValue(std.uni.toLower(name), 0);
        }

        /**
         * @see Part#getHeaderNames()
         */
        override
        Collection!string getHeaderNames() {
            return _headers.keySet();
        }

        /**
         * @see Part#getHeaders(string)
         */
        override
        Collection!string getHeaders(string name) {
            return _headers.getValues(name);
        }

        /**
         * @see Part#getInputStream()
         */
        override
        InputStream getInputStream() {
            if (_file != null) {
                // written to a file, whether temporary or not
                return new BufferedInputStream(new FileInputStream(_file));
            } else {
                // part content is in memory
                return new ByteArrayInputStream(_bout.getBuf(), 0, _bout.size());
            }
        }

        /**
         * @see Part#getSubmittedFileName()
         */
        override
        string getSubmittedFileName() {
            return getContentDispositionFilename();
        }

        byte[] getBytes() {
            if (_bout != null)
                return _bout.toByteArray();
            return null;
        }

        /**
         * @see Part#getName()
         */
        override
        string getName() {
            return _name;
        }

        /**
         * @see Part#getSize()
         */
        override
        long getSize() {
            return _size;
        }

        /**
         * @see Part#write(string)
         */
        override
        void write(string fileName) {
            if (_file == null) {
                _temporary = false;

                // part data is only in the ByteArrayOutputStream and never been written to disk
                _file = new File(_tmpDir, fileName);

                BufferedOutputStream bos = null;
                try {
                    bos = new BufferedOutputStream(new FileOutputStream(_file));
                    _bout.writeTo(bos);
                    bos.flush();
                } finally {
                    if (bos != null)
                        bos.close();
                    _bout = null;
                }
            } else {
                // the part data is already written to a temporary file, just rename it
                _temporary = false;

                Path src = _file.toPath();
                Path target = src.resolveSibling(fileName);
                Files.move(src, target, StandardCopyOption.REPLACE_EXISTING);
                _file = target.toFile();
            }
        }

        /**
         * Remove the file, whether or not Part.write() was called on it (ie no longer temporary)
         *
         * @see Part#delete()
         */
        override
        void delete() {
            if (_file != null && _file.exists())
                _file.delete();
        }

        /**
         * Only remove tmp files.
         *
         * @throws IOException if unable to delete the file
         */
        void cleanUp() {
            if (_temporary && _file != null && _file.exists())
                _file.delete();
        }

        /**
         * Get the file
         *
         * @return the file, if any, the data has been written to.
         */
        File getFile() {
            return _file;
        }

        /**
         * Get the filename from the content-disposition.
         *
         * @return null or the filename
         */
        string getContentDispositionFilename() {
            return _filename;
        }
    }

    /**
     * @param in            Request input stream
     * @param contentType   Content-Type header
     * @param config        MultipartConfigElement
     * @param contextTmpDir javax.servlet.context.tempdir
     */
    MultiPartFormInputStream(InputStream in, string contentType, MultipartConfigElement config, File contextTmpDir) {
        _contentType = contentType;
        _config = config;
        _contextTmpDir = contextTmpDir;
        if (_contextTmpDir == null)
            _contextTmpDir = new File(System.getProperty("java.io.tmpdir"));

        if (_config == null)
            _config = new MultipartConfigElement(_contextTmpDir.getAbsolutePath());

        if (in instanceof ServletInputStream) {
            if (((ServletInputStream) in).isFinished()) {
                _parts = EMPTY_MAP;
                _parsed = true;
                return;
            }
        }
        _in = new BufferedInputStream(in);
    }

    /**
     * @return whether the list of parsed parts is empty
     */
    bool isEmpty() {
        if (_parts == null)
            return true;

        Collection<List!(Part)> values = _parts.values();
        for (List!(Part) partList : values) {
            if (partList.size() != 0)
                return false;
        }

        return true;
    }

    /**
     * Get the already parsed parts.
     *
     * @return the parts that were parsed
     */
    deprecated("")
    Collection!(Part) getParsedParts() {
        if (_parts == null)
            return Collections.emptyList();

        Collection<List!(Part)> values = _parts.values();
        List!(Part) parts = new ArrayList<>();
        for (List!(Part) o : values) {
            List!(Part) asList = LazyList.getList(o, false);
            parts.addAll(asList);
        }
        return parts;
    }

    /**
     * Delete any tmp storage for parts, and clear out the parts list.
     */
    void deleteParts() {
        if (!_parsed)
            return;

        Collection!(Part) parts;
        try {
            parts = getParts();
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        MultiException err = new MultiException();

        for (Part p : parts) {
            try {
                ((MultiPart) p).cleanUp();
            } catch (Exception e) {
                err.add(e);
            }
        }
        _parts.clear();

        err.ifExceptionThrowRuntime();
    }

    /**
     * Parse, if necessary, the multipart data and return the list of Parts.
     *
     * @return the parts
     * @throws IOException if unable to get the parts
     */
    Collection!(Part) getParts() {
        if (!_parsed)
            parse();
        throwIfError();

        Collection<List!(Part)> values = _parts.values();
        List!(Part) parts = new ArrayList<>();
        for (List!(Part) o : values) {
            List!(Part) asList = LazyList.getList(o, false);
            parts.addAll(asList);
        }
        return parts;
    }

    /**
     * Get the named Part.
     *
     * @param name the part name
     * @return the parts
     * @throws IOException if unable to get the part
     */
    Part getPart(string name) {
        if (!_parsed)
            parse();
        throwIfError();
        return _parts.getValue(name, 0);
    }

    /**
     * Throws an exception if one has been latched.
     *
     * @throws IOException the exception (if present)
     */
    protected void throwIfError() {
        if (_err != null) {
            _err.addSuppressed(new Exception());
            if (_err instanceof IOException)
                throw (IOException) _err;
            if (_err instanceof IllegalStateException)
                throw (IllegalStateException) _err;
            throw new IllegalStateException(_err);
        }
    }

    /**
     * Parse, if necessary, the multipart stream.
     */
    protected void parse() {
        // have we already parsed the input?
        if (_parsed)
            return;
        _parsed = true;

        try {

            // initialize
            _parts = new MultiMap<>();

            // if its not a multipart request, don't parse it
            if (_contentType == null || !_contentType.startsWith("multipart/form-data"))
                return;

            // sort out the location to which to write the files
            if (_config.getLocation() == null)
                _tmpDir = _contextTmpDir;
            else if ("".equals(_config.getLocation()))
                _tmpDir = _contextTmpDir;
            else {
                File f = new File(_config.getLocation());
                if (f.isAbsolute())
                    _tmpDir = f;
                else
                    _tmpDir = new File(_contextTmpDir, _config.getLocation());
            }

            if (!_tmpDir.exists())
                _tmpDir.mkdirs();

            string contentTypeBoundary = "";
            int bstart = _contentType.indexOf("boundary=");
            if (bstart >= 0) {
                int bend = _contentType.indexOf(";", bstart);
                bend = (bend < 0 ? _contentType.length() : bend);
                contentTypeBoundary = QuotedStringTokenizer.unquote(value(_contentType.substring(bstart, bend)).strip());
            }

            Handler handler = new Handler();
            MultiPartParser parser = new MultiPartParser(handler, contentTypeBoundary);

            // Create a buffer to store data from stream //
            byte[] data = new byte[_bufferSize];
            int len = 0;

            /*
             * keep running total of size of bytes read from input and throw an exception if exceeds MultipartConfigElement._maxRequestSize
             */
            long total = 0;

            while (true) {

                len = _in.read(data);

                if (len > 0) {
                    total += len;
                    if (_config.getMaxRequestSize() > 0 && total > _config.getMaxRequestSize()) {
                        _err = new IllegalStateException("Request exceeds maxRequestSize (" + _config.getMaxRequestSize() + ")");
                        return;
                    }

                    ByteBuffer buffer = BufferUtils.toBuffer(data);
                    buffer.limit(len);
                    if (parser.parse(buffer, false))
                        break;

                    if (buffer.hasRemaining())
                        throw new IllegalStateException("Buffer did not fully consume");

                } else if (len == -1) {
                    parser.parse(BufferUtils.EMPTY_BUFFER, true);
                    break;
                }

            }

            // check for exceptions
            if (_err != null) {
                return;
            }

            // check we read to the end of the message
            if (parser.getState() != MultiPartParser.State.END) {
                if (parser.getState() == MultiPartParser.State.PREAMBLE)
                    _err = new IOException("Missing initial multi part boundary");
                else
                    _err = new IOException("Incomplete Multipart");
            }

            version(HUNT_DEBUG) {
                tracef("Parsing Complete %s err=%s", parser, _err);
            }

        } catch (Exception e) {
            _err = e;
            return;
        }

    }

    class Handler : MultiPartParser.Handler {
        private MultiPart _part = null;
        private string contentDisposition = null;
        private string contentType = null;
        private MultiMap!string headers = new MultiMap<>();

        override
        bool messageComplete() {
            return true;
        }

        override
        void parsedField(string key, string value) {
            // Add to headers and mark if one of these fields. //
            headers.put(std.uni.toLower(key), value);
            if (key.equalsIgnoreCase("content-disposition"))
                contentDisposition = value;
            else if (key.equalsIgnoreCase("content-type"))
                contentType = value;

            // Transfer encoding is not longer considers as it is deprecated as per
            // https://tools.ietf.org/html/rfc7578#section-4.7

        }

        override
        bool headerComplete() {
            version(HUNT_DEBUG) {
                tracef("headerComplete %s", this);
            }

            try {
                // Extract content-disposition
                bool form_data = false;
                if (contentDisposition == null) {
                    throw new IOException("Missing content-disposition");
                }

                QuotedStringTokenizer tok = new QuotedStringTokenizer(contentDisposition, ";", false, true);
                string name = null;
                string filename = null;
                while (tok.hasMoreTokens()) {
                    string t = tok.nextToken().strip();
                    string tl = std.uni.toLower(t);
                    if (tl.startsWith("form-data"))
                        form_data = true;
                    else if (tl.startsWith("name="))
                        name = value(t);
                    else if (tl.startsWith("filename="))
                        filename = filenameValue(t);
                }

                // Check disposition
                if (!form_data)
                    throw new IOException("Part not form-data");

                // It is valid for reset and submit buttons to have an empty name.
                // If no name is supplied, the browser skips sending the info for that field.
                // However, if you supply the empty string as the name, the browser sends the
                // field, with name as the empty string. So, only continue this loop if we
                // have not yet seen a name field.
                if (name == null)
                    throw new IOException("No name in part");


                // create the new part
                _part = new MultiPart(name, filename);
                _part.setHeaders(headers);
                _part.setContentType(contentType);
                _parts.add(name, _part);

                try {
                    _part.open();
                } catch (IOException e) {
                    _err = e;
                    return true;
                }
            } catch (Exception e) {
                _err = e;
                return true;
            }

            return false;
        }

        override
        bool content(ByteBuffer buffer, bool last) {
            if (_part == null)
                return false;

            if (BufferUtils.hasContent(buffer)) {
                try {
                    _part.write(buffer.array(), buffer.arrayOffset() + buffer.position(), buffer.remaining());
                } catch (IOException e) {
                    _err = e;
                    return true;
                }
            }

            if (last) {
                try {
                    _part.close();
                } catch (IOException e) {
                    _err = e;
                    return true;
                }
            }

            return false;
        }

        override
        void startPart() {
            reset();
        }

        override
        void earlyEOF() {
            version(HUNT_DEBUG)
                tracef("Early EOF %s", this.outer);
        }

        void reset() {
            _part = null;
            contentDisposition = null;
            contentType = null;
            headers = new MultiMap<>();
        }
    }

    void setDeleteOnExit(bool deleteOnExit) {
        _deleteOnExit = deleteOnExit;
    }

    void setWriteFilesWithFilenames(bool writeFilesWithFilenames) {
        _writeFilesWithFilenames = writeFilesWithFilenames;
    }

    bool isWriteFilesWithFilenames() {
        return _writeFilesWithFilenames;
    }

    bool isDeleteOnExit() {
        return _deleteOnExit;
    }

    /* ------------------------------------------------------------ */
    private string value(string nameEqualsValue) {
        int idx = nameEqualsValue.indexOf('=');
        string value = nameEqualsValue.substring(idx + 1).strip();
        return QuotedStringTokenizer.unquoteOnly(value);
    }

    /* ------------------------------------------------------------ */
    private string filenameValue(string nameEqualsValue) {
        int idx = nameEqualsValue.indexOf('=');
        string value = nameEqualsValue.substring(idx + 1).strip();

        if (value.matches(".??[a-z,A-Z]\\:\\\\[^\\\\].*")) {
            // incorrectly escaped IE filenames that have the whole path
            // we just strip any leading & trailing quotes and leave it as is
            char first = value.charAt(0);
            if (first == '"' || first == '\'')
                value = value.substring(1);
            char last = value.charAt(value.length() - 1);
            if (last == '"' || last == '\'')
                value = value.substring(0, value.length() - 1);

            return value;
        } else
            // unquote the string, but allow any backslashes that don't
            // form a valid escape sequence to remain as many browsers
            // even on *nix systems will not escape a filename containing
            // backslashes
            return QuotedStringTokenizer.unquoteOnly(value, true);
    }

}


/**
 * Java Class represntation of an {@link MultipartConfig} annotation value.
 *
 * @since Servlet 3.0
 */
class MultipartConfigElement {

    private string location;
    private long maxFileSize;
    private long maxRequestSize;
    private int fileSizeThreshold;

    /**
     * Constructs an instance with defaults for all but location.
     *
     * @param location defualts to "" if values is null.
     */
    this(string location) {
        if (location == null) {
            this.location = "";
        } else {
            this.location = location;
        }
        this.maxFileSize = -1L;
        this.maxRequestSize = -1L;
        this.fileSizeThreshold = 0;
    }

    /**
     * Constructs an instance with all values specified.
     *
     * @param location the directory location where files will be stored
     * @param maxFileSize the maximum size allowed for uploaded files
     * @param maxRequestSize the maximum size allowed for
     * multipart/form-data requests
     * @param fileSizeThreshold the size threshold after which files will
     * be written to disk
     */
    this(string location, long maxFileSize,
            long maxRequestSize, int fileSizeThreshold) {
        if (location == null) {
            this.location = "";
        } else {
            this.location = location;
        }
        this.maxFileSize = maxFileSize;
        this.maxRequestSize = maxRequestSize;
        this.fileSizeThreshold = fileSizeThreshold;
    }

    /**
     * Constructs an instance from a {@link MultipartConfig} annotation value.
     *
     * @param annotation the annotation value
     */
    // this(MultipartConfig annotation) {
    //     this.location = annotation.location();
    //     this.fileSizeThreshold = annotation.fileSizeThreshold();
    //     this.maxFileSize = annotation.maxFileSize();
    //     this.maxRequestSize = annotation.maxRequestSize();
    // }

    /**
     * Gets the directory location where files will be stored.
     *
     * @return the directory location where files will be stored
     */
    string getLocation() {
        return this.location;
    }

    /**
     * Gets the maximum size allowed for uploaded files.
     *
     * @return the maximum size allowed for uploaded files
     */
    long getMaxFileSize() {
        return this.maxFileSize;
    }

    /**
     * Gets the maximum size allowed for multipart/form-data requests.
     *
     * @return the maximum size allowed for multipart/form-data requests
     */
    long getMaxRequestSize() {
        return this.maxRequestSize;
    }

    /**
     * Gets the size threshold after which files will be written to disk.
     *
     * @return the size threshold after which files will be written to disk
     */
    int getFileSizeThreshold() {
        return this.fileSizeThreshold;
    }
}


/**
 * <p> This class represents a part or form item that was received within a
 * <code>multipart/form-data</code> POST request.
 * 
 * @since Servlet 3.0
 */
interface Part {

    /**
     * Gets the content of this part as an <tt>InputStream</tt>
     * 
     * @return The content of this part as an <tt>InputStream</tt>
     * @throws IOException If an error occurs in retrieving the contet
     * as an <tt>InputStream</tt>
     */
    InputStream getInputStream();

    /**
     * Gets the content type of this part.
     *
     * @return The content type of this part.
     */
    string getContentType();

    /**
     * Gets the name of this part
     *
     * @return The name of this part as a <tt>string</tt>
     */
    string getName();

    /**
     * Gets the file name specified by the client
     *
     * @return the submitted file name
     *
     * @since Servlet 3.1
     */
    string getSubmittedFileName();

    /**
     * Returns the size of this fille.
     *
     * @return a <code>long</code> specifying the size of this part, in bytes.
     */
    long getSize();

    /**
     * A convenience method to write this uploaded item to disk.
     * 
     * <p>This method is not guaranteed to succeed if called more than once for
     * the same part. This allows a particular implementation to use, for
     * example, file renaming, where possible, rather than copying all of the
     * underlying data, thus gaining a significant performance benefit.
     *
     * @param fileName the name of the file to which the stream will be
     * written. The file is created relative to the location as
     * specified in the MultipartConfig
     *
     * @throws IOException if an error occurs.
     */
    void write(string fileName);

    /**
     * Deletes the underlying storage for a file item, including deleting any
     * associated temporary disk file.
     *
     * @throws IOException if an error occurs.
     */
    void remove();

    /**
     *
     * Returns the value of the specified mime header
     * as a <code>string</code>. If the Part did not include a header
     * of the specified name, this method returns <code>null</code>.
     * If there are multiple headers with the same name, this method
     * returns the first header in the part.
     * The header name is case insensitive. You can use
     * this method with any request header.
     *
     * @param name		a <code>string</code> specifying the
     *				header name
     *
     * @return			a <code>string</code> containing the
     *				value of the requested
     *				header, or <code>null</code>
     *				if the part does not
     *				have a header of that name
     */
    string getHeader(string name);

    /**
     * Gets the values of the Part header with the given name.
     *
     * <p>Any changes to the returned <code>Collection</code> must not 
     * affect this <code>Part</code>.
     *
     * <p>Part header names are case insensitive.
     *
     * @param name the header name whose values to return
     *
     * @return a (possibly empty) <code>Collection</code> of the values of
     * the header with the given name
     */
    Collection!string getHeaders(string name);

    /**
     * Gets the header names of this Part.
     *
     * <p>Some servlet containers do not allow
     * servlets to access headers using this method, in
     * which case this method returns <code>null</code>
     *
     * <p>Any changes to the returned <code>Collection</code> must not 
     * affect this <code>Part</code>.
     *
     * @return a (possibly empty) <code>Collection</code> of the header
     * names of this Part
     */
    Collection!string getHeaderNames();

}
++/