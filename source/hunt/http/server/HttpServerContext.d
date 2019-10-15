module hunt.http.server.HttpServerContext;

import hunt.http.server.HttpServerConnection;
import hunt.http.codec.http.stream.HttpOutputStream;
import hunt.http.codec.http.model.MetaData;

import hunt.io.Common;
import hunt.io.BufferedOutputStream;
import hunt.Exceptions;
import hunt.logging.ConsoleLogger;

/**
 * 
 */
class HttpServerContext {

    private HttpRequest _httpRequest;
    private HttpResponse _httpResponse; 
    private HttpOutputStream _httpOutputStream;
    private HttpServerConnection _connection;
    private BufferedOutputStream _bufferedOutputStream; 
    private int _bufferSize = 8 * 1024;

    this(HttpRequest request, HttpResponse response, 
            HttpOutputStream outputStream, HttpServerConnection connection) {
        _httpRequest = request;
        _httpResponse = response;
        _httpOutputStream = outputStream;
        _connection = connection;
    }

    HttpRequest httpRequest() {
        return _httpRequest;
    }

    void httpRequest(HttpRequest request) {
        _httpRequest = request;
    }

    HttpResponse httpResponse() {
        return _httpResponse;
    } 

    void httpResponse(HttpResponse response) {
        _httpResponse = response;
    }

    // HttpOutputStream outputStream() {
    //     return _httpOutputStream;
    // }
    
    OutputStream outputStream() {
        if (_bufferedOutputStream is null) {
            _bufferedOutputStream = new BufferedOutputStream(_httpOutputStream, bufferSize);
        }
        return _bufferedOutputStream;
    }


    void bufferSize(int size) { _bufferSize = size; }

    int bufferSize() { return _bufferSize; }

    void flush() {
        if (_bufferedOutputStream !is null) {
            _bufferedOutputStream.flush();
        } 
    }

    bool isCommitted() {
        return _httpOutputStream !is null && _httpOutputStream.isCommitted();
    }

    void write(string value) {
        write(cast(byte[])value, 0, cast(int)value.length);
    }

    void write(byte[] buffer, int offset, int len) {
        try {
            outputStream().write(buffer, offset, len);
        } catch (IOException e) {
            version(HUNT_DEBUG) warning(e.msg);
            version(HUNT_HTTP_DEBUG) warning(e);
            // errorf("write data exception " ~ uri.toString(), e);
            // throw new Exception(e);
        }
    }

    void end() {
        if (_bufferedOutputStream !is null) {
            _bufferedOutputStream.close();
        } 
        else {
            _httpOutputStream.close();
        }        
    }
   
}