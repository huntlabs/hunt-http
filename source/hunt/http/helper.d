module hunt.http.helper;

import hunt.http.client.http.SimpleHTTPClient;
import hunt.http.client.http.SimpleHTTPClientConfiguration;
import hunt.http.client.http.SimpleResponse;

import hunt.http.server.http.HTTP2ServerBuilder;
import hunt.http.server.http.SimpleHTTPServer;
import hunt.http.server.http.SimpleHTTPServerConfiguration;
import hunt.http.server.http.router.handler.HTTPBodyHandler;

import hunt.http.codec.http.model.HttpVersion;

import hunt.util.concurrent.Promise;
import hunt.util.concurrent.CompletableFuture;

import hunt.net.secure.SecureSessionFactory;


private __gshared SimpleHTTPClient _httpClient;
private __gshared SimpleHTTPClient _httpsClient;
private __gshared SimpleHTTPClient _plaintextHTTP2Client;

// shared this() {
//     _httpClient = new SimpleHTTPClient();
// }

/**
 * The singleton HTTP client to send all requests.
 * The HTTP client manages HTTP connection in the BoundedAsynchronousPool automatically.
 * The default protocol is HTTP 1.1.
 *
 * @return HTTP client singleton instance.
 */
SimpleHTTPClient httpClient() { 
    synchronized {
        if(_httpClient is null)
            _httpClient = new SimpleHTTPClient();
    }
    return _httpClient;
}


/**
 * The singleton HTTP client to send all requests.
 * The HTTP client manages HTTP connection in the BoundedAsynchronousPool automatically.
 * The protocol is plaintext HTTP 2.0.
 *
 * @return HTTP client singleton instance.
 */
SimpleHTTPClient plaintextHTTP2Client() {
    synchronized {
        if(_plaintextHTTP2Client is null) {
            SimpleHTTPClientConfiguration configuration = new SimpleHTTPClientConfiguration();
            configuration.setProtocol(HttpVersion.HTTP_2.asString());
            _plaintextHTTP2Client = new SimpleHTTPClient(configuration);
        }
    }
    return _plaintextHTTP2Client;
}

/**
 * The singleton HTTPs client to send all requests.
 * The HTTPs client manages HTTP connection in the BoundedAsynchronousPool automatically.
 * It uses ALPN to determine HTTP 1.1 or HTTP 2.0 protocol.
 *
 * @return HTTPs client singleton instance.
 */
SimpleHTTPClient httpsClient() {
    synchronized {
        if(_httpsClient is null) {
            SimpleHTTPClientConfiguration configuration = new SimpleHTTPClientConfiguration();
            configuration.setSecureConnectionEnabled(true);
            _httpsClient = new SimpleHTTPClient(configuration);
        }
    }
    return _httpsClient;
}

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
 * Use fluent API to create an new HTTP server instance.
 *
 * @return HTTP server builder.
 */
HTTP2ServerBuilder httpServer() {
    return new HTTP2ServerBuilder().httpServer();
}

/**
 * Create a new HTTP2 server. It uses the plaintext HTTP2 protocol.
 *
 * @return HTTP server builder.
 */
HTTP2ServerBuilder plaintextHTTP2Server() {
    SimpleHTTPServerConfiguration configuration = new SimpleHTTPServerConfiguration();
    configuration.setProtocol(HttpVersion.HTTP_2.asString());
    return httpServer(configuration);
}

/**
 * Create a new HTTP server.
 *
 * @param serverConfiguration The server configuration.
 * @return HTTP server builder
 */
HTTP2ServerBuilder httpServer(SimpleHTTPServerConfiguration serverConfiguration) {
    return httpServer(serverConfiguration, new HTTPBodyConfiguration());
}

/**
 * Create a new HTTP server.
 *
 * @param serverConfiguration   HTTP server configuration.
 * @param httpBodyConfiguration HTTP body process configuration.
 * @return HTTP server builder.
 */
HTTP2ServerBuilder httpServer(SimpleHTTPServerConfiguration serverConfiguration,
                                     HTTPBodyConfiguration httpBodyConfiguration) {
    return new HTTP2ServerBuilder().httpServer(serverConfiguration, httpBodyConfiguration);
}


/**
 * Create a new HTTPs server.
 *
 * @return HTTP server builder.
 */
HTTP2ServerBuilder httpsServer() {
    return new HTTP2ServerBuilder().httpsServer();
}

/**
 * Create a new HTTPs server.
 *
 * @param secureSessionFactory The secure session factory. We provide JDK or OpenSSL secure session factory.
 * @return HTTP server builder.
 */
HTTP2ServerBuilder httpsServer(SecureSessionFactory secureSessionFactory) {
    return new HTTP2ServerBuilder().httpsServer(secureSessionFactory);
}

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
