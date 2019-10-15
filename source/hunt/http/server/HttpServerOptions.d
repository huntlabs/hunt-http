module hunt.http.server.HttpServerOptions;

import hunt.http.HttpOptions;
import hunt.net.TcpSslOptions;
import hunt.net.NetServerOptions;

class HttpServerOptions : HttpOptions {
    private NetServerOptions _netServerOptions;

    this() {
        _netServerOptions = new NetServerOptions();
        this(_netServerOptions);
    }

    this(NetServerOptions options) {
        _netServerOptions = options;
        super(options);
    }

    override NetServerOptions getTcpConfiguration() {
        return _netServerOptions;
    }


    /**
     *
     * @return the port
     */
    int getPort() {
        return _netServerOptions.getPort();
    }

    /**
     * Set the port
     *
     * @param port  the port
     * @return a reference to this, so the API can be used fluently
     */
    HttpServerOptions setPort(int port) {
        _netServerOptions.setPort(port);
        return this;
    }

    /**
     *
     * @return the host
     */
    string getHost() {
        return _netServerOptions.getHost();
    }

    /**
     * Set the host
     * @param host  the host
     * @return a reference to this, so the API can be used fluently
     */
    HttpServerOptions setHost(string host) {
        _netServerOptions.setHost(host);
        return this;
    }

}