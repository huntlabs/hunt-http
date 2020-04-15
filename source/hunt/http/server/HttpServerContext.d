module hunt.http.server.HttpServerContext;

import hunt.http.server.HttpServerConnection;
import hunt.http.server.HttpServerRequest;
import hunt.http.server.HttpServerResponse;

import hunt.http.HttpOutputStream;

import hunt.http.HttpMetaData;
import hunt.http.HttpStatus;

import hunt.io.Common;
import hunt.io.BufferedOutputStream;
import hunt.Exceptions;
import hunt.Functions;
import hunt.logging.ConsoleLogger;


/**
 * 
 */
class HttpServerContext {

    private HttpServerRequest _httpRequest;
    private HttpServerResponse _httpResponse; 
    private HttpOutputStream _httpOutputStream;
    private HttpServerConnection _connection;
    private BufferedOutputStream _bufferedOutputStream; 
    private int _bufferSize = 8 * 1024;

    // private int _status = HttpStatus.OK_200;

    // Action1!ByteBuffer _contentHandler;
    // Action1!HttpRequest _contentCompleteHandler;
    // Action1!HttpRequest _messageCompleteHandler;

    this(HttpServerRequest request, HttpServerResponse response, 
            HttpOutputStream outputStream, HttpServerConnection connection) {
        _httpRequest = request;
        _httpResponse = response;
        _httpOutputStream = outputStream;
        _connection = connection;
    }

    HttpServerRequest httpRequest() {
        return _httpRequest;
    }

    void httpRequest(HttpServerRequest request) {
        _httpRequest = request;
    }

    HttpServerResponse httpResponse() {
        return _httpResponse;
    } 

    void httpResponse(HttpServerResponse response) {
        _httpResponse = response;
        _httpOutputStream.setMetaData(response);  // binding the response with a httpOutputStream
    }

    // HttpServerContext onContent(Action1!ByteBuffer handler) {
    //     _contentHandler = handler;
    //     return this;
    // }

    // HttpServerContext onContentComplete(Action1!HttpServerContext handler) {
    //     _contentCompleteHandler = handler;
    //     return this;
    // }

    // HttpServerContext onMessageComplete(Action1!HttpServerContext handler) {
    //     _messageCompleteHandler = handler;
    //     return this;
    // }

    HttpServerConnection connection() {
        return _connection;
    }
    
    int getConnectionId() {
        return _connection.getId();
    }

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