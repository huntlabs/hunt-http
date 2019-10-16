module hunt.http.router.handler.HttpBodyOptions;

import std.file;

/**
 * 
 */
class HttpBodyOptions {

    private int bodyBufferThreshold = 512 * 1024;
    private int maxRequestSize = 64 * 1024 * 1024;
    private int maxFileSize = 64 * 1024 * 1024;
    private string tempFilePath = "./temp";
    private string charset = "UTF-8";
    // private MultipartConfigElement multipartConfigElement = new MultipartConfigElement(tempFilePath, maxFileSize, maxRequestSize, bodyBufferThreshold);

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

    // MultipartConfigElement getMultipartConfigElement() {
    //     return multipartConfigElement;
    // }

    // void setMultipartConfigElement(MultipartConfigElement multipartConfigElement) {
    //     this.multipartConfigElement = multipartConfigElement;
    // }
}