module hunt.http.helper;

import hunt.http.client.http.SimpleHttpClient;
import hunt.http.client.http.SimpleHttpClientConfiguration;
import hunt.http.client.http.SimpleResponse;

import hunt.http.server.http.Http2ServerBuilder;
import hunt.http.server.http.SimpleHttpServer;
import hunt.http.server.http.SimpleHttpServerConfiguration;
import hunt.http.server.http.router.handler.HttpBodyHandler;

import hunt.http.codec.http.model.HttpVersion;

import hunt.util.concurrent.Promise;
import hunt.util.concurrent.CompletableFuture;

import hunt.net.secure.SecureSessionFactory;


private __gshared SimpleHttpClient _httpClient;
private __gshared SimpleHttpClient _httpsClient;
private __gshared SimpleHttpClient _plaintextHttp2Client;

// shared this() {
//     _httpClient = new SimpleHttpClient();
// }

/**
 * The singleton HTTP client to send all requests.
 * The HTTP client manages HTTP connection in the BoundedAsynchronousPool automatically.
 * The default protocol is HTTP 1.1.
 *
 * @return HTTP client singleton instance.
 */
SimpleHttpClient httpClient() { 
    synchronized {
        if(_httpClient is null)
            _httpClient = new SimpleHttpClient();
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
SimpleHttpClient plaintextHttp2Client() {
    synchronized {
        if(_plaintextHttp2Client is null) {
            SimpleHttpClientConfiguration configuration = new SimpleHttpClientConfiguration();
            configuration.setProtocol(HttpVersion.HTTP_2.asString());
            _plaintextHttp2Client = new SimpleHttpClient(configuration);
        }
    }
    return _plaintextHttp2Client;
}

/**
 * The singleton HTTPs client to send all requests.
 * The HTTPs client manages HTTP connection in the BoundedAsynchronousPool automatically.
 * It uses ALPN to determine HTTP 1.1 or HTTP 2.0 protocol.
 *
 * @return HTTPs client singleton instance.
 */
SimpleHttpClient httpsClient() {
    synchronized {
        if(_httpsClient is null) {
            SimpleHttpClientConfiguration configuration = new SimpleHttpClientConfiguration();
            configuration.setSecureConnectionEnabled(true);
            _httpsClient = new SimpleHttpClient(configuration);
        }
    }
    return _httpsClient;
}

/**
 * Create a new HTTP client instance.
 *
 * @return A new HTTP client instance.
 */
SimpleHttpClient createHttpClient() {
    return new SimpleHttpClient();
}

/**
 * Create a new HTTP client instance.
 *
 * @param configuration HTTP client configuration.
 * @return A new HTTP client instance.
 */
SimpleHttpClient createHttpClient(SimpleHttpClientConfiguration configuration) {
    return new SimpleHttpClient(configuration);
}

/**
* Create a new HTTPs client.
*
* @param secureSessionFactory The secure session factory. We provide JDK or OpenSSL secure session factory.
* @return A new HTTPs client.
*/
SimpleHttpClient createHttpsClient(SecureSessionFactory secureSessionFactory) {
    SimpleHttpClientConfiguration configuration = new SimpleHttpClientConfiguration();
    configuration.setSecureSessionFactory(secureSessionFactory);
    configuration.setSecureConnectionEnabled(true);
    return new SimpleHttpClient(configuration);
}


/**
 * Use fluent API to create an new HTTP server instance.
 *
 * @return HTTP server builder.
 */
Http2ServerBuilder httpServer() {
    return new Http2ServerBuilder().httpServer();
}

/**
 * Create a new HTTP2 server. It uses the plaintext HTTP2 protocol.
 *
 * @return HTTP server builder.
 */
Http2ServerBuilder plaintextHttp2Server() {
    SimpleHttpServerConfiguration configuration = new SimpleHttpServerConfiguration();
    configuration.setProtocol(HttpVersion.HTTP_2.asString());
    return httpServer(configuration);
}

/**
 * Create a new HTTP server.
 *
 * @param serverConfiguration The server configuration.
 * @return HTTP server builder
 */
Http2ServerBuilder httpServer(SimpleHttpServerConfiguration serverConfiguration) {
    return httpServer(serverConfiguration, new HttpBodyConfiguration());
}

/**
 * Create a new HTTP server.
 *
 * @param serverConfiguration   HTTP server configuration.
 * @param httpBodyConfiguration HTTP body process configuration.
 * @return HTTP server builder.
 */
Http2ServerBuilder httpServer(SimpleHttpServerConfiguration serverConfiguration,
                                     HttpBodyConfiguration httpBodyConfiguration) {
    return new Http2ServerBuilder().httpServer(serverConfiguration, httpBodyConfiguration);
}


/**
 * Create a new HTTPs server.
 *
 * @return HTTP server builder.
 */
Http2ServerBuilder httpsServer() {
    return new Http2ServerBuilder().httpsServer();
}

/**
 * Create a new HTTPs server.
 *
 * @param secureSessionFactory The secure session factory. We provide JDK or OpenSSL secure session factory.
 * @return HTTP server builder.
 */
Http2ServerBuilder httpsServer(SecureSessionFactory secureSessionFactory) {
    return new Http2ServerBuilder().httpsServer(secureSessionFactory);
}

/**
 * Create a new HTTP server instance
 *
 * @return A new HTTP server instance
 */
SimpleHttpServer createHttpServer() {
    return new SimpleHttpServer();
}

/**
 * Create a new HTTP server instance
 *
 * @param configuration HTTP server configuration
 * @return A new HTTP server instance
 */
SimpleHttpServer createHttpServer(SimpleHttpServerConfiguration configuration) {
    return new SimpleHttpServer(configuration);
}
