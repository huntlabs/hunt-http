module hunt.http.codec.http.stream.BufferedHttpOutputStream;

import hunt.http.codec.http.stream.HttpOutputStream;

import hunt.io;

/**
 * 
 */
class BufferedHttpOutputStream :BufferedNetOutputStream {

    this(HttpOutputStream output, int bufferSize) {
        super(output, bufferSize);
    }
}
