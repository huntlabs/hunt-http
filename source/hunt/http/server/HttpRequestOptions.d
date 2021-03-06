module hunt.http.server.HttpRequestOptions;

import std.file;
import std.path;

/**
 * 
 */
class HttpRequestOptions {

    private int bodyBufferThreshold = 512 * 1024;
    private int maxRequestSize = 64 * 1024 * 1024;
    private int maxFileSize = 64 * 1024 * 1024;
    private string tempFilePath = "./temp";
    private string tempFileAbsolutePath = "/temp";
    private string charset = "UTF-8";
    private string _defaultLanguage = "en-US";

    this() {
        tempFilePath = tempDir();
        tempFileAbsolutePath = tempFilePath;
    }

    int getBodyBufferThreshold() {
        return bodyBufferThreshold;
    }

    void setBodyBufferThreshold(int bodyBufferThreshold) {
        this.bodyBufferThreshold = bodyBufferThreshold;
    }

    int getMaxRequestSize() {
        return maxRequestSize;
    }

    void setMaxRequestSize(int maxRequestSize) {
        this.maxRequestSize = maxRequestSize;
    }

    int getMaxFileSize() {
        return maxFileSize;
    }

    void setMaxFileSize(int size) {
        maxFileSize = size;
    }

    string getTempFilePath() {
        return tempFilePath;
    }

    string getTempFileAbsolutePath() {
        return tempFileAbsolutePath;
    }

    void setTempFilePath(string tempFilePath) {
        this.tempFilePath = tempFilePath;
        string rootPath = dirName(thisExePath);
        tempFileAbsolutePath = buildPath(rootPath, tempFilePath);
    }

    string getCharset() {
        return charset;
    }

    void setCharset(string charset) {
        this.charset = charset;
    }

    string defaultLanguage() {
        return _defaultLanguage;
    }

    void defaultLanguage(string langId) {
        _defaultLanguage = langId;
    }
}