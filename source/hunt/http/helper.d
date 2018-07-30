module hunt.http.helper;

import hunt.http.client.http.SimpleHTTPClient;
import hunt.http.client.http.SimpleHTTPClientConfiguration;
import hunt.http.client.http.SimpleResponse;

import hunt.util.concurrent.Promise;
import hunt.util.concurrent.CompletableFuture;

import hunt.net.secure.SecureSessionFactory;

/**
    * Create a new HTTPs client.
    *
    * @param secureSessionFactory The secure session factory. We provide JDK or OpenSSL secure session factory.
    * @return A new HTTPs client.
    */
static SimpleHTTPClient createHTTPsClient(SecureSessionFactory secureSessionFactory) {
    SimpleHTTPClientConfiguration configuration = new SimpleHTTPClientConfiguration();
    configuration.setSecureSessionFactory(secureSessionFactory);
    configuration.setSecureConnectionEnabled(true);
    return new SimpleHTTPClient(configuration);
}