module hunt.http.server.http.SimpleResponse;

import hunt.http.codec.http.model;
import hunt.http.codec.http.stream.BufferedHttpOutputStream;
import hunt.http.codec.http.stream.HttpOutputStream;

import hunt.util.exception;
import hunt.util.functional;
import hunt.io;
import hunt.util.common;

import hunt.logging;
import std.range;

alias Request = MetaData.Request;
alias Response = MetaData.Response;

class SimpleResponse : Closeable { 

    Response response;
    HttpOutputStream output;
    HttpURI uri;
    BufferedHttpOutputStream bufferedOutputStream;
    int bufferSize = 8 * 1024;
    string characterEncoding = "UTF-8";
    bool asynchronous;

    this(Response response, HttpOutputStream output, HttpURI uri) {
        this.output = output;
        this.response = response;
        this.uri = uri;
    }

    HttpVersion getHttpVersion() {
        return response.getHttpVersion();
    }

    HttpFields getFields() {
        return response.getFields();
    }

    long getContentLength() {
        return response.getContentLength();
    }

    InputRange!HttpField iterator() {
        return response.iterator();
    }

    int getStatus() {
        return response.getStatus();
    }

    string getReason() {
        return response.getReason();
    }

    // void forEach(Consumer<? super HttpField> action) {
    //     response.forEach(action);
    // }

    Supplier!HttpFields getTrailerSupplier() {
        return response.getTrailerSupplier();
    }

    void setTrailerSupplier(Supplier!HttpFields trailers) {
        response.setTrailerSupplier(trailers);
    }

    // Spliterator<HttpField> spliterator() {
    //     return response.spliterator();
    // }

    Response getResponse() {
        return response;
    }

    bool isAsynchronous() {
        return asynchronous;
    }

    void setAsynchronous(bool asynchronous) {
        this.asynchronous = asynchronous;
    }

    OutputStream getOutputStream() {
        if (bufferedOutputStream is null) {
            bufferedOutputStream = new BufferedHttpOutputStream(output, bufferSize);
        }
        return bufferedOutputStream;
    }

    string getCharacterEncoding() {
        return characterEncoding;
    }

    void setCharacterEncoding(string characterEncoding) {
        this.characterEncoding = characterEncoding;
    }

    int getBufferSize() {
        return bufferSize;
    }

    void setBufferSize(int bufferSize) {
        this.bufferSize = bufferSize;
    }

    bool isClosed() {
        return output.isClosed();
    }

    void close() {
        if (bufferedOutputStream !is null) {
            bufferedOutputStream.close();
        } 
        else {
            getOutputStream().close();
        }
    }

    void flush() {
        if (bufferedOutputStream !is null) {
            bufferedOutputStream.flush();
        } 
    }

    bool isCommitted() {
        return output !is null && output.isCommitted();
    }


    SimpleResponse setStatus(int status) {
        response.setStatus(status);
        return this;
    }

    SimpleResponse setReason(string reason) {
        response.setReason(reason);
        return this;
    }

    SimpleResponse setHttpVersion(HttpVersion httpVersion) {
        response.setHttpVersion(httpVersion);
        return this;
    }

    SimpleResponse put(HttpHeader header, string value) {
        getFields().put(header, value);
        return this;
    }

    SimpleResponse put(string header, string value) {
        getFields().put(header, value);
        return this;
    }

    SimpleResponse add(HttpHeader header, string value) {
        getFields().add(header, value);
        return this;
    }

    SimpleResponse add(string name, string value) {
        getFields().add(name, value);
        return this;
    }

    SimpleResponse addCookie(Cookie cookie) {
        response.getFields().add(HttpHeader.SET_COOKIE, CookieGenerator.generateSetCookie(cookie));
        return this;
    }

    SimpleResponse write(string value) {
        write(cast(byte[])value, 0, cast(int)value.length);
        return this;
    }

    SimpleResponse write(byte[] b) {
        return write(b, 0, cast(int)b.length);
    }

    SimpleResponse write(byte[] b, int off, int len) {
        try {
            getOutputStream().write(b, off, len);
        } catch (IOException e) {
            errorf("write data exception " ~ uri.toString(), e);
        }
        return this;
    }

    SimpleResponse end(string value) {
        return write(value).end();
    }

    SimpleResponse end() {
        // IO.close(this);
        try {
            this.close();
        }
        catch (IOException ignore) {
		}
        return this;
    }

    SimpleResponse end(byte[] b) {
        return write(b).end();
    }
}
