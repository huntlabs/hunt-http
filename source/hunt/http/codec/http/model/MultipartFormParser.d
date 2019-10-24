module hunt.http.codec.http.model.MultipartFormParser;

import hunt.http.codec.http.model.MultiException;
import hunt.http.MultipartOptions;
import hunt.http.codec.http.model.MultipartParser;
import hunt.http.MultipartForm;

import hunt.collection;
import hunt.io;
import hunt.Exceptions;
import hunt.logging;
import hunt.text.Common;
import hunt.text.QuotedStringTokenizer;
import hunt.text.StringUtils;

import std.array;
import std.conv;
import std.concurrency : initOnce;
import std.file;
import std.path;
import std.regex;
import std.string;
import std.uni;

deprecated("Using MultipartFormParser instead.")
alias MultipartFormInputStream = MultipartFormParser;


void deleteOnExit(string file) {
    if(file.exists) {
        version(HUNT_HTTP_DEBUG) infof("File removed: %s", file);
        file.remove();
    } else {
        warningf("File not exists: %s", file);
    }
}

/**
 * MultipartFormParser
 * <p>
 * Handle a MultipartForm Mime input stream, breaking it up on the boundary into files and strings.
 *
 * @see <a href="https://tools.ietf.org/html/rfc7578">https://tools.ietf.org/html/rfc7578</a>
 */
class MultipartFormParser {

    static MultiMap!(Part) EMPTY_MAP() {
        __gshared MultiMap!(Part) inst;
        return initOnce!inst(new MultiMap!(Part)(Collections.emptyMap!(string, List!(Part))()));
    }
    // __gshared MultipartOptions DEFAULT_MULTIPART_CONFIG;
    // __gshared MultiMap!(Part) EMPTY_MAP;

    private int _bufferSize = 16 * 1024;
    protected InputStream _in;
    protected MultipartOptions _config;
    protected string _contentType;
    protected MultiMap!(Part) _parts;
    protected Exception _err;
    protected string _tmpDir;
    protected string _contextTmpDir;
    protected bool _deleteOnExit;
    protected bool _parsed;

    deprecated("It's removed. Just using MultipartForm instead.")
    alias MultiPart = MultipartForm;

    /**
     * @param input         Request input stream
     * @param contentType   Content-Type header
     * @param config        MultipartOptions
     * @param contextTmpDir tempdir
     */
    this(InputStream input, string contentType, MultipartOptions config, string contextTmpDir) {
        _contentType = contentType;
        _config = config;
        if (contextTmpDir.empty)
            _contextTmpDir = tempDir();
        else
            _contextTmpDir = contextTmpDir;

        if (_config is null) {
            string rootPath = dirName(thisExePath);
            string abslutePath = buildPath(rootPath, _contextTmpDir);
            if (!abslutePath.exists())
                abslutePath.mkdirRecurse();
            _config = new MultipartOptions(abslutePath);
        }

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
                (cast(MultipartForm) p).cleanUp();
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

        scope(exit) _in.close();

        try {
            doParse();
        } catch (Exception e) {
            warningf("Error occurred while parsing: %s", e.msg);
            version(HUNT_HTTP_DEBUG) warning(e);
            _err = e;
        }
    }

    private void doParse() {
        // initialize
        _parts = new MultiMap!Part();

        // if its not a multipart request, don't parse it
        if (_contentType.empty() || !_contentType.startsWith("multipart/form-data"))
            return;

        // sort out the location to which to write the files
        string location = _config.getLocation();
        if (location.empty())
            _tmpDir = _contextTmpDir;
        else 
            _tmpDir = buildPath(_contextTmpDir, location);

        version(HUNT_HTTP_DEBUG) {
            if (!_tmpDir.exists())
                _tmpDir.mkdirRecurse();
        }

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

        /**
         * keep running total of size of bytes read from input and throw an exception if exceeds MultipartOptions._maxRequestSize
         */
        long total = 0;
        // _in.position(0); // The InputStream may be read, so reset it before reading it again.

        version(HUNT_HTTP_DEBUG) {
            int size = _in.available();
            tracef("available: %d", size);
            if(size == 0) {
                warning("no data available in inputStream");
            }
        }

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
                version(HUNT_DEBUG) trace("no more data avaiable");
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

        version(HUNT_HTTP_DEBUG) {
            if(_err is null) {
                info("Parsing completed");
            } else {
                warningf("Parsing Completed with error: %s", _err);
            }
        }
    }

    class Handler : MultipartParserHandler {
        private MultipartForm _part = null;
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
            version(HUNT_HTTP_DEBUG) {
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
                _part = new MultipartForm(name, filename, _config);
                _part.setTmpDir(_tmpDir);
                _part.setHeaders(headers);
                _part.setContentType(contentType);
                _parts.add(name, _part);

                try {
                    _part.open();
                } catch (IOException e) {
                    version(HUNT_HTTP_DEBUG) warning(e.msg);
                    version(HUNT_HTTP_DEBUG) warning(e);
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
            version(HUNT_HTTP_DEBUG)
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

