module hunt.http.client.http.PlaintextHTTP2ClientSingleton;

import hunt.http.client.http.SimpleHTTPClient;
import hunt.http.client.http.SimpleHTTPClientConfiguration;

import hunt.http.codec.http.model.HttpVersion;
// import hunt.http.utils.lang.AbstractLifeCycle;

/**
 * 
 */
class PlaintextHTTP2ClientSingleton { // : AbstractLifeCycle 

    private __gshared PlaintextHTTP2ClientSingleton ourInstance; //  = new PlaintextHTTP2ClientSingleton();

    shared static this()
    {
        ourInstance = new PlaintextHTTP2ClientSingleton();
    }

    static PlaintextHTTP2ClientSingleton getInstance() {
        return ourInstance;
    }

    private SimpleHTTPClient _httpClient;

    private this() {
        // start();
    }

    SimpleHTTPClient httpClient() {
        return _httpClient;
    }

    protected void init() {
        SimpleHTTPClientConfiguration configuration = new SimpleHTTPClientConfiguration();
        configuration.setProtocol(HttpVersion.HTTP_2.asString());
        _httpClient = new SimpleHTTPClient(configuration);
    }

    protected void destroy() {
        if (_httpClient !is null) {
            // _httpClient.stop();
            _httpClient = null;
        }
    }
}
