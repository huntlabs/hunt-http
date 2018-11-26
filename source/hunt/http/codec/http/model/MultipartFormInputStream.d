module hunt.http.codec.http.model.MultipartFormInputStream;

import hunt.http.codec.http.model.MultiException;
import hunt.http.codec.http.model.MultipartConfig;
import hunt.http.codec.http.model.MultipartParser;

import hunt.container;
import hunt.io;
import hunt.lang.exception;
import hunt.logging;
import hunt.string;

import std.array;
import std.conv;
import std.file;
import std.path;
import std.regex;
import std.string;
import std.uni;


void deleteOnExit(string file) {
    if(file.exists) {
        version(HUNT_DEBUG) infof("File removed: %s", file);
        file.remove();
    } else {
        warningf("File not exists: %s", file);
    }
}

/**
 * MultiPartInputStream
 * <p>
 * Handle a MultiPart Mime input stream, breaking it up on the boundary into files and strings.
 *
 * @see <a href="https://tools.ietf.org/html/rfc7578">https://tools.ietf.org/html/rfc7578</a>
 */
class MultipartFormInputStream {
    
    private int _bufferSize = 16 * 1024;
    __gshared MultipartConfig __DEFAULT_MULTIPART_CONFIG;
    __gshared MultiMap!(Part) EMPTY_MAP;
    protected InputStream _in;
    protected MultipartConfig _config;
    protected string _contentType;
    protected MultiMap!(Part) _parts;
    protected Exception _err;
    protected string _tmpDir;
    protected string _contextTmpDir;
    protected bool _deleteOnExit;
    protected bool _writeFilesWithFilenames;
    protected bool _parsed;

    shared static this() {
        __DEFAULT_MULTIPART_CONFIG = new MultipartConfig(tempDir());
        EMPTY_MAP = new MultiMap!(Part)(Collections.emptyMap!(string, List!(Part))());
    }

    class MultiPart : Part {
        protected string _name;
        protected string _filename;
        protected string _file;
        protected OutputStream _out;
        protected ByteArrayOutputStream _bout;
        protected string _contentType;
        protected MultiMap!string _headers;
        protected long _size = 0;
        protected bool _temporary = true;
        private bool isWriteToFile = false;

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
            if (isWriteFilesWithFilenames() && !_filename.empty) {
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
                throw new IllegalStateException("Multipart Mime part " ~ _name ~ " exceeds max filesize");

            if (this.outer._config.getFileSizeThreshold() > 0 && 
                _size + 1 > this.outer._config.getFileSizeThreshold() && _file is null) {
                createFile();
            } 
            _out.write(b);
            _size++;
        }

        protected void write(byte[] bytes, int offset, int length) {
            if (this.outer._config.getMaxFileSize() > 0 && _size + length > this.outer._config.getMaxFileSize())
                throw new IllegalStateException("Multipart Mime part " ~ _name ~ " exceeds max filesize");

            if (this.outer._config.getFileSizeThreshold() > 0
                    && _size + length > this.outer._config.getFileSizeThreshold() && _file is null) {
                createFile();
            } 
            _out.write(bytes, offset, length);
            _size += length;
        }

        protected void createFile() {
            /*
             * Some statics just to make the code below easier to understand This get optimized away during the compile anyway
             */
            // bool USER = true;
            // bool WORLD = false;
            _file= buildPath(this.outer._tmpDir, "MultiPart-" ~ StringUtils.randomId());
            version(HUNT_DEBUG) trace("Creating temp file: ", _file);

            // _file = File.createTempFile("MultiPart", "", this.outer._tmpDir);
            // _file.setReadable(false, WORLD); // (reset) disable it for everyone first
            // _file.setReadable(true, USER); // enable for user only

            // if (_deleteOnExit)
            //     _file.deleteOnExit();
            FileOutputStream fos = new FileOutputStream(_file);
            BufferedOutputStream bos = new BufferedOutputStream(fos);

            if (_size > 0 && _out !is null) {
                // already written some bytes, so need to copy them into the file
                _out.flush();
                _bout.writeTo(bos);
                _out.close();
            }
            _bout = null;
            _out = bos;
            isWriteToFile = true;
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
            if (name is null)
                return null;
            return _headers.getValue(std.uni.toLower(name), 0);
        }

        /**
         * @see Part#getHeaderNames()
         */
        // override
        string[] getHeaderNames() {
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
            if (_file !is null) {
                // written to a file, whether temporary or not
                return new FileInputStream(_file);
            } else {
                // part content is in memory
                return new ByteArrayInputStream(_bout.getBuffer(), 0, _bout.size());
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
            if (_bout !is null)
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
            version(HUNT_DEBUG) infof("writing file: _file=%s, target=%s", _file, fileName);
            if(fileName.empty) {
                warning("Target file name can't be empty.");
                return;
            }
            _temporary = false;
            if (_file.empty) {
                // part data is only in the ByteArrayOutputStream and never been written to disk
                _file = buildPath(_tmpDir, fileName);

                FileOutputStream bos = null;
                try {
                    bos = new FileOutputStream(_file);
                    _bout.writeTo(bos);
                    bos.flush();
                } finally {
                    if (bos !is null)
                        bos.close();
                    _bout = null;
                }
            } else {
                // the part data is already written to a temporary file, just rename it
                string target = dirName(_file) ~ dirSeparator ~ fileName;
                version(HUNT_DEBUG) tracef("src: %s, target: %s", _file, target);
                rename(_file, target);
                _file = target;
            }
        }

        /**
         * Remove the file, whether or not Part.write() was called on it (ie no longer temporary)
         *
         * @see Part#delete()
         */
        override
        void remove() {
            if (!_file.empty && _file.exists())
                _file.remove();
        }

        /**
         * Only remove tmp files.
         *
         * @throws IOException if unable to delete the file
         */
        void cleanUp() {
            if (_temporary && _file !is null && _file.exists())
                _file.remove();
        }

        /**
         * Get the file
         *
         * @return the file, if any, the data has been written to.
         */
        string getFile() {
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
     * @param input            Request input stream
     * @param contentType   Content-Type header
     * @param config        MultipartConfig
     * @param contextTmpDir javax.servlet.context.tempdir
     */
    this(InputStream input, string contentType, MultipartConfig config, string contextTmpDir) {
        _contentType = contentType;
        _config = config;
        if (contextTmpDir.empty)
            _contextTmpDir = tempDir();
        else
            _contextTmpDir = contextTmpDir;

        if (_config is null)
            _config = new MultipartConfig(_contextTmpDir.asAbsolutePath().array);

        // if (input instanceof ServletInputStream) {
        //     if (((ServletInputStream) input).isFinished()) {
        //         _parts = EMPTY_MAP;
        //         _parsed = true;
        //         return;
        //     }
        // }
        _in = new BufferedInputStream(input);
    }

    /**
     * @return whether the list of parsed parts is empty
     */
    bool isEmpty() {
        if (_parts is null)
            return true;

        List!(Part)[] values = _parts.values();
        foreach (List!(Part) partList ; values) {
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
    // deprecated("")
    // Collection!(Part) getParsedParts() {
    //     if (_parts is null)
    //         return Collections.emptyList();

    //     Collection<List!(Part)> values = _parts.values();
    //     List!(Part) parts = new ArrayList<>();
    //     for (List!(Part) o : values) {
    //         List!(Part) asList = LazyList.getList(o, false);
    //         parts.addAll(asList);
    //     }
    //     return parts;
    // }

    /**
     * Delete any tmp storage for parts, and clear out the parts list.
     */
    void deleteParts() {
        if (!_parsed)
            return;

        Part[] parts;
        try {
            parts = getParts();
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
        MultiException err = new MultiException();

        foreach (Part p ; parts) {
            try {
                (cast(MultiPart) p).cleanUp();
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
    Part[] getParts() {
        if (!_parsed)
            parse();
        throwIfError();

        List!(Part)[] values = _parts.values();
        Part[] parts;
        foreach (List!(Part) o ; values) {
            foreach(Part p; o) {
                parts ~= p;
            }
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
        if (_err !is null) {
            _err.next = (new Exception(""));
            auto ioException = cast(IOException) _err;
            if (ioException !is null)
                throw ioException;
            auto illegalStateException = cast(IllegalStateException) _err;
            if (illegalStateException !is null)
                throw illegalStateException;
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
            doParse();
        } catch (Exception e) {
            warningf("Error occurred while parsing: %s", e.msg);
            _err = e;
        }
    }

    private void doParse() {
        // initialize
        _parts = new MultiMap!Part();

        // if its not a multipart request, don't parse it
        if (_contentType is null || !_contentType.startsWith("multipart/form-data"))
            return;

        // sort out the location to which to write the files
        string location = _config.getLocation();
        if (location.empty())
            _tmpDir = _contextTmpDir;
        else 
                _tmpDir = buildPath(_contextTmpDir, location);

        if (!_tmpDir.exists())
            _tmpDir.mkdirRecurse();

        string contentTypeBoundary = "";
        int bstart = cast(int)_contentType.indexOf("boundary=");
        if (bstart >= 0) {
            ptrdiff_t bend = _contentType.indexOf(";", bstart);
            bend = (bend < 0 ? _contentType.length : bend);
            contentTypeBoundary = QuotedStringTokenizer.unquote(value(_contentType[bstart .. bend]).strip());
        }

        Handler handler = new Handler();
        MultipartParser parser = new MultipartParser(handler, contentTypeBoundary);

        // Create a buffer to store data from stream //
        byte[] data = new byte[_bufferSize];
        int len = 0;

        /*
            * keep running total of size of bytes read from input and throw an exception if exceeds MultipartConfig._maxRequestSize
            */
        long total = 0;

        while (true) {

            len = _in.read(data);

            if (len > 0) {
                total += len;
                if (_config.getMaxRequestSize() > 0 && total > _config.getMaxRequestSize()) {
                    _err = new IllegalStateException("Request exceeds maxRequestSize (" ~ 
                        _config.getMaxRequestSize().to!string() ~ ")");
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
        if (_err !is null) {
            return;
        }

        // check we read to the end of the message
        if (parser.getState() != MultipartParser.State.END) {
            if (parser.getState() == MultipartParser.State.PREAMBLE)
                _err = new IOException("Missing initial multi part boundary");
            else
                _err = new IOException("Incomplete Multipart");
        }

        version(HUNT_DEBUG) {
            tracef("Parsing Complete %s err=%s", parser, _err);
        }
    }

    class Handler : MultipartParserHandler {
        private MultiPart _part = null;
        private string contentDisposition = null;
        private string contentType = null;
        private MultiMap!string headers;

        this() {
            super();
            headers = new MultiMap!string();
        }

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
                if (contentDisposition is null) {
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
                if (name is null)
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
            if (_part is null)
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
            headers = new MultiMap!string();
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
        ptrdiff_t idx = nameEqualsValue.indexOf('=');
        string value = nameEqualsValue[idx + 1 .. $].strip();
        return QuotedStringTokenizer.unquoteOnly(value);
    }

    /* ------------------------------------------------------------ */
    private string filenameValue(string nameEqualsValue) {
        ptrdiff_t idx = nameEqualsValue.indexOf('=');
        string value = nameEqualsValue[idx + 1 .. $].strip();
        auto pattern = ctRegex!(".??[a-z,A-Z]\\:\\\\[^\\\\].*");
        // if (value.matches(".??[a-z,A-Z]\\:\\\\[^\\\\].*")) {
        auto m = matchFirst(value, pattern);
        if(!m.empty) {
            // incorrectly escaped IE filenames that have the whole path
            // we just strip any leading & trailing quotes and leave it as is
            char first = value[0];
            if (first == '"' || first == '\'')
                value = value[1 .. $];
            char last = value[$ - 1];
            if (last == '"' || last == '\'')
                value = value[0 .. $ - 1];

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
    string[] getHeaderNames();

    string toString();

}
