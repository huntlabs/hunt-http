module hunt.http.client.http.HttpClientSingleton;

import hunt.http.client.http.SimpleHttpClient;

// import hunt.http.utils.lang.AbstractLifeCycle;

/**
 * 
 */
class HttpClientSingleton  { // : AbstractLifeCycle

    private __gshared HttpClientSingleton ourInstance; // = new HttpClientSingleton();

    shared static this()
    {
        ourInstance = new HttpClientSingleton();
    }

    static HttpClientSingleton getInstance() {
        return ourInstance;
    }

    private SimpleHttpClient _httpClient;

    private this() {
        // start();
    }

    SimpleHttpClient httpClient() {
        return _httpClient;
    }

    protected void init() {
        _httpClient = new SimpleHttpClient();
    }

    protected void destroy() {
        if (_httpClient !is null) {
            // _httpClient.stop();
            _httpClient = null;
        }
    }
}
