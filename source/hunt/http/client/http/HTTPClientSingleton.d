module hunt.http.client.http.HTTPClientSingleton;

import hunt.http.client.http.SimpleHTTPClient;

// import hunt.http.utils.lang.AbstractLifeCycle;

/**
 * 
 */
class HTTPClientSingleton  { // : AbstractLifeCycle

    private __gshared HTTPClientSingleton ourInstance; // = new HTTPClientSingleton();

    shared static this()
    {
        ourInstance = new HTTPClientSingleton();
    }

    static HTTPClientSingleton getInstance() {
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
        _httpClient = new SimpleHTTPClient();
    }

    protected void destroy() {
        if (_httpClient !is null) {
            // _httpClient.stop();
            _httpClient = null;
        }
    }
}
