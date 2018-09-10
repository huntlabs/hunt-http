module hunt.http.client.http.HttpsClientSingleton;

import hunt.http.client.http.SimpleHttpClient;
import hunt.http.client.http.SimpleHttpClientConfiguration;

// import hunt.http.utils.lang.AbstractLifeCycle;

/**
 * 
 */
class HttpsClientSingleton { // : AbstractLifeCycle 
    private __gshared HttpsClientSingleton ourInstance; // = new HttpsClientSingleton();

    shared static this()
    {
        ourInstance = new HttpsClientSingleton();        
    }

    static HttpsClientSingleton getInstance() {
        return ourInstance;
    }

    private SimpleHttpClient httpClient;

    private this() {
        // start();
    }

    SimpleHttpClient httpsClient() {
        return httpClient;
    }

    // override
    protected void init() {
        SimpleHttpClientConfiguration configuration = new SimpleHttpClientConfiguration();
        configuration.setSecureConnectionEnabled(true);
        httpClient = new SimpleHttpClient(configuration);
    }

    // override
    protected void destroy() {
        if (httpClient !is null) {
            // httpClient.stop();
            httpClient = null;
        }
    }
}
