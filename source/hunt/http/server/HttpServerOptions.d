module hunt.http.server.HttpServerOptions;

import hunt.http.server.ClientAuth;
import hunt.http.server.HttpRequestOptions;

import hunt.http.HttpOptions;
import hunt.net.TcpSslOptions;
import hunt.net.NetServerOptions;

/**
 * 
 */
class HttpServerOptions : HttpOptions {

    /**
     * Default value of whether client auth is required (SSL/TLS) = No
     */
    enum ClientAuth DEFAULT_CLIENT_AUTH = ClientAuth.NONE;

    private NetServerOptions _netServerOptions;
    private HttpRequestOptions _httpRequestOptions;
    private ClientAuth clientAuth;

    this() {
        this(new NetServerOptions(), new HttpRequestOptions());
    }

    this(NetServerOptions options) {
        this(options, new HttpRequestOptions());
    }

    this(NetServerOptions serverOptions, HttpRequestOptions requestOptions) {
        _netServerOptions = serverOptions;
        _httpRequestOptions = requestOptions;
        clientAuth = DEFAULT_CLIENT_AUTH;
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
    HttpServerOptions setPort(ushort port) {
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

    /**
     * 
     */
    ClientAuth getClientAuth() {
        return clientAuth;
    }

    /**
     * Set whether client auth is required
     *
     * @param clientAuth One of "NONE, REQUEST, REQUIRED". If it's set to "REQUIRED" then server will require the
     *                   SSL cert to be presented otherwise it won't accept the request. If it's set to "REQUEST" then
     *                   it won't mandate the certificate to be presented, basically make it optional.
     * @return a reference to this, so the API can be used fluently
     */
    HttpServerOptions setClientAuth(ClientAuth clientAuth) {
        this.clientAuth = clientAuth;
        return this;
    }    

    /* ------------------------------ Session APIs ------------------------------ */

    private string sessionIdParameterName = "hunt-session-id";
    private int defaultMaxInactiveInterval = 10 * 60; //second

    string getSessionIdParameterName() {
        return sessionIdParameterName;
    }

    void setSessionIdParameterName(string name) {
        this.sessionIdParameterName = name;
    }

    int getDefaultMaxInactiveInterval() {
        return defaultMaxInactiveInterval;
    }

    void setDefaultMaxInactiveInterval(int interval) {
        this.defaultMaxInactiveInterval = interval;
    }
}


