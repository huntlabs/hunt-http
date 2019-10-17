module hunt.http.server.HttpRequestOptions;

import hunt.http.codec.http.model.MultipartOptions;

import std.file;

/**
 * 
 */
class HttpRequestOptions {

    private int bodyBufferThreshold = 512 * 1024;
    private int maxRequestSize = 64 * 1024 * 1024;
    private int maxFileSize = 64 * 1024 * 1024;
    private string tempFilePath = "./temp";
    private string charset = "UTF-8";
    private MultipartOptions _multipartOptions;

    this() {
        tempFilePath = tempDir();
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

    string getTempFilePath() {
        return tempFilePath;
    }

    void setTempFilePath(string tempFilePath) {
        this.tempFilePath = tempFilePath;
    }

    string getCharset() {
        return charset;
    }

    void setCharset(string charset) {
        this.charset = charset;
    }

    MultipartOptions getMultipartOptions() {
        if(_multipartOptions is null) {
            _multipartOptions = new MultipartOptions(tempFilePath, maxFileSize, maxRequestSize, bodyBufferThreshold); 
        }
        return _multipartOptions;
    }

    void setMultipartConfig(MultipartOptions options) {
        this._multipartOptions = options;
    }
}