module hunt.http.server.http.SimpleHttpServerConfiguration;

import hunt.http.codec.http.stream.Http2Configuration;

class SimpleHttpServerConfiguration : Http2Configuration {

    private string host;
    private int port;

    /**
     * Get the HTTP server host name.
     *
     * @return The HTTP server host name.
     */
    string getHost() {
        return host;
    }

    /**
     * Set the HTTP server host name.
     *
     * @param host The HTTP server host name.
     */
    void setHost(string host) {
        this.host = host;
    }

    /**
     * Get the HTTP server TCP port.
     *
     * @return The HTTP server TCP port.
     */
    int getPort() {
        return port;
    }

    /**
     * Set the HTTP server TCP port.
     *
     * @param port The HTTP server TCP port.
     */
    void setPort(int port) {
        this.port = port;
    }

}
