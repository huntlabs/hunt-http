module hunt.http.MultipartOptions;

import std.concurrency : initOnce;
import std.file;

deprecated("Using MultipartOptions instead.")
alias MultipartConfig = MultipartOptions;

/**
 * Class represntation of an {@link MultipartConfig} value.
 */
class MultipartOptions {

    static MultipartOptions Default() {
        __gshared MultipartOptions inst;
        return initOnce!inst(new MultipartOptions(tempDir()));
    }

    private string location;
    private long maxFileSize;
    private long maxRequestSize;
    private int fileSizeThreshold;
    private bool _writeFilesWithFilenames;

    /**
     * Constructs an instance with defaults for all but location.
     *
     * @param location defualts to "" if values is null.
     */
    this(string location) {
        if (location is null) {
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
        if (location is null) {
            this.location = "";
        } else {
            this.location = location;
        }
        this.maxFileSize = maxFileSize;
        this.maxRequestSize = maxRequestSize;
        this.fileSizeThreshold = fileSizeThreshold;
    }


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

    
    void setWriteFilesWithFilenames(bool writeFilesWithFilenames) {
        _writeFilesWithFilenames = writeFilesWithFilenames;
    }

    bool isWriteFilesWithFilenames() {
        return _writeFilesWithFilenames;
    }

}
