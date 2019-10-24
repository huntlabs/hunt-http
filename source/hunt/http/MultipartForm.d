module hunt.http.MultipartForm;

import hunt.http.MultipartOptions;

import hunt.collection;
import hunt.io;
import hunt.Exceptions;
import hunt.logging.ConsoleLogger;
import hunt.text.StringUtils;

import std.array;
import std.conv;
import std.file;
import std.path;
import std.string;
import std.uni;

deprecated("Using MultipartForm instead.")
alias MultiPart = MultipartForm;

/**
 * <p> This class represents a part or form item that was received within a
 * <code>multipart/form-data</code> POST request.
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
     */
    string getSubmittedFileName();

    /**
     * Returns the size of this fille.
     *
     * @return a <code>long</code> specifying the size of this part, in bytes.
     */
    long getSize();

    string getFile();

    byte[] getBytes();

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
     * specified in the MultipartOptions
     *
     * @throws IOException if an error occurs.
     */
    void writeTo(string fileName);

    deprecated("Using writeTo instead.")
    void write(string fileName);


    /**
     * Save the content to a temp file 
     */
    void flush();

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

/**
 * 
 */
class MultipartForm : Part {
    private string _name;
    private string _filename;
    private string _file;
    private OutputStream _out;
    private ByteArrayOutputStream _bout;
    private string _contentType;
    private MultiMap!string _headers;
    private long _size = 0;

    private MultipartOptions _config;
    private bool _isWriteToFile = false;
    private bool _temporary = true;
    private bool _writeFilesWithFilenames;
    private string _tmpDir;

    this(string name, string filename, MultipartOptions options) {
        _name = name;
        _filename = filename;
        _config = options;
        _tmpDir = tempDir();
    }

    override
    string toString() {
        return format("Part{name=%s, fileName=%s, contentType=%s, size=%d, tmp=%b, file=%s}", 
            _name, _filename, _contentType, _size, _temporary, _file);
    }

    void setTmpDir(string dir) {
        _tmpDir = dir;
    }

    package void setContentType(string contentType) {
        _contentType = contentType;
    }

    package void open() {
        // We will either be writing to a file, if it has a filename on the content-disposition
        // and otherwise a byte-array-input-stream, OR if we exceed the getFileSizeThreshold, we
        // will need to change to write to a file.
        if (_config.isWriteFilesWithFilenames() && !_filename.empty) {
            createFile();
        } else {
            // Write to a buffer in memory until we discover we've exceed the
            // MultipartOptions fileSizeThreshold
            _out = _bout = new ByteArrayOutputStream();
        }
    }

    package void close() {
        _out.close();
    }

    package void write(int b) {
        if (_config.getMaxFileSize() > 0 && _size + 1 > _config.getMaxFileSize())
            throw new IllegalStateException("Multipart Mime part " ~ _name ~ " exceeds max filesize");

        if (_config.getFileSizeThreshold() > 0 && 
            _size + 1 > _config.getFileSizeThreshold() && 
            !_filename.empty() && _file.empty()) {
            createFile();
        } 
        _out.write(b);
        _size++;
    }

    package void write(byte[] bytes, int offset, int length) {
        if (_config.getMaxFileSize() > 0 && _size + length > _config.getMaxFileSize())
            throw new IllegalStateException("Multipart Mime part " ~ _name ~ " exceeds max filesize");

        if (_config.getFileSizeThreshold() > 0
                && _size + length > _config.getFileSizeThreshold() 
                && !_filename.empty() && _file.empty()) {
            createFile();
        } 
        _out.write(bytes, offset, length);
        _size += length;
    }

    private void createFile() {
        /*
         * Some statics just to make the code below easier to understand This get optimized away during the compile anyway
         */
        // bool USER = true;
        // bool WORLD = false;
        _file= buildPath(_tmpDir, "Multipart-" ~ StringUtils.randomId());
        version(HUNT_HTTP_DEBUG) infof("Creating temp file for multipart: %s", _file);

        // _file = File.createTempFile("Multipart", "", _tmpDir);
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
        _isWriteToFile = true;
    }

    package void setHeaders(MultiMap!string headers) {
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
    
    deprecated("Using writeTo instead.")
    void write(string fileName) {
        writeTo(fileName);
    }

    /**
     * @see Part#write(string)
     */
    void writeTo(string fileName) {
        if(fileName.empty) {
            warning("The target file name can't be empty.");
            return;
        }
        _temporary = false;
        if (_file.empty) {
            // part data is only in the ByteArrayOutputStream and never been written to disk
            _file = buildPath(_tmpDir, fileName);
            version(HUNT_HTTP_DEBUG) infof("writing to file: _file=%s", _file);

            scope FileOutputStream bos = null;
            try {
                bos = new FileOutputStream(_file);
                _bout.writeTo(bos);
                bos.flush();
            } finally {
                if (bos !is null)
                    bos.close();

                version(HUNT_HTTP_DEBUG_MORE) infof("closing file: _file=%s", _file);
                _bout = null;
            }
        } else {
            // the part data is already written to a temporary file, just rename it
            string target = buildPath(dirName(_file), fileName);
            if(_file != target) {
                version(HUNT_HTTP) tracef("moving file, src: %s, target: %s", _file, target);
                rename(_file, target);
                _file = target;
            }
        }
    }

    void flush() {
        if(_file.empty) {
            writeTo("Multipart-" ~ StringUtils.randomId());
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
    