module hunt.http.server.HttpServerOptions;

import hunt.http.HttpOptions;
import hunt.net.TcpSslOptions;
import hunt.net.NetServerOptions;
import hunt.http.server.HttpRequestOptions;

/**
 * 
 */
class HttpServerOptions : HttpOptions {
    private NetServerOptions _netServerOptions;
    private HttpRequestOptions _httpRequestOptions;

    this() {
        this(new NetServerOptions(), new HttpRequestOptions());
    }

    this(NetServerOptions options) {
        this(options, new HttpRequestOptions());
    }

    this(NetServerOptions serverOptions, HttpRequestOptions requestOptions) {
        _netServerOptions = serverOptions;
        _httpRequestOptions = requestOptions;
        super(serverOptions);
    }

    override NetServerOptions getTcpConfiguration() {
        return _netServerOptions;
    }

    HttpRequestOptions requestOptions() {
        return _httpRequestOptions;
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