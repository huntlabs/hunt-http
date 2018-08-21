module hunt.http.helper;

import hunt.http.client.http.SimpleHTTPClient;
import hunt.http.client.http.SimpleHTTPClientConfiguration;
import hunt.http.client.http.SimpleResponse;

import hunt.http.server.http.SimpleHTTPServer;
import hunt.http.server.http.SimpleHTTPServerConfiguration;

import hunt.util.concurrent.Promise;
import hunt.util.concurrent.CompletableFuture;

import hunt.net.secure.SecureSessionFactory;

/**
 * Create a new HTTP client instance.
 *
 * @return A new HTTP client instance.
 */
SimpleHTTPClient createHTTPClient() {
    return new SimpleHTTPClient();
}

/**
 * Create a new HTTP client instance.
 *
 * @param configuration HTTP client configuration.
 * @return A new HTTP client instance.
 */
SimpleHTTPClient createHTTPClient(SimpleHTTPClientConfiguration configuration) {
    return new SimpleHTTPClient(configuration);
}

/**
* Create a new HTTPs client.
*
* @param secureSessionFactory The secure session factory. We provide JDK or OpenSSL secure session factory.
* @return A new HTTPs client.
*/
SimpleHTTPClient createHTTPsClient(SecureSessionFactory secureSessionFactory) {
    SimpleHTTPClientConfiguration configuration = new SimpleHTTPClientConfiguration();
    configuration.setSecureSessionFactory(secureSessionFactory);
    configuration.setSecureConnectionEnabled(true);
    return new SimpleHTTPClient(configuration);
}

/**
 * Create a new HTTPs server.
 *
 * @return HTTP server builder.
 */
// HTTP2ServerBuilder httpsServer() {
//     return new HTTP2ServerBuilder().httpsServer();
// }

/**
 * Create a new HTTPs server.
 *
 * @param secureSessionFactory The secure session factory. We provide JDK or OpenSSL secure session factory.
 * @return HTTP server builder.
 */
// HTTP2ServerBuilder httpsServer(SecureSessionFactory secureSessionFactory) {
//     return new HTTP2ServerBuilder().httpsServer(secureSessionFactory);
// }

/**
 * Create a new HTTP server instance
 *
 * @return A new HTTP server instance
 */
SimpleHTTPServer createHTTPServer() {
    return new SimpleHTTPServer();
}

/**
 * Create a new HTTP server instance
 *
 * @param configuration HTTP server configuration
 * @return A new HTTP server instance
 */
SimpleHTTPServer createHTTPServer(SimpleHTTPServerConfiguration configuration) {
    return new SimpleHTTPServer(configuration);
}
