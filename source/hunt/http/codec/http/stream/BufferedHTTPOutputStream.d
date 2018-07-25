module hunt.http.codec.http.stream.BufferedHTTPOutputStream;

import hunt.http.codec.http.stream.HTTPOutputStream;

import hunt.io;

/**
 * 
 */
class BufferedHTTPOutputStream :BufferedNetOutputStream {

    this(HTTPOutputStream output, int bufferSize) {
        super(output, bufferSize);
    }
}
