module hunt.http.client.http.HTTPsClientSingleton;

import hunt.http.client.http.SimpleHTTPClient;
import hunt.http.client.http.SimpleHTTPClientConfiguration;

// import hunt.http.utils.lang.AbstractLifeCycle;

/**
 * 
 */
class HTTPsClientSingleton { // : AbstractLifeCycle 
    private __gshared HTTPsClientSingleton ourInstance; // = new HTTPsClientSingleton();

    shared static this()
    {
        ourInstance = new HTTPsClientSingleton();        
    }

    static HTTPsClientSingleton getInstance() {
        return ourInstance;
    }

    private SimpleHTTPClient httpClient;

    private this() {
        // start();
    }

    SimpleHTTPClient httpsClient() {
        return httpClient;
    }

    // override
    protected void init() {
        SimpleHTTPClientConfiguration configuration = new SimpleHTTPClientConfiguration();
        configuration.setSecureConnectionEnabled(true);
        httpClient = new SimpleHTTPClient(configuration);
    }

    // override
    protected void destroy() {
        if (httpClient !is null) {
            // httpClient.stop();
            httpClient = null;
        }
    }
}
