module hunt.http.router.RequestAcceptor;

import hunt.http.server.HttpServerContext;

/**
 * 
 */
interface RequestAcceptor {
    void accept(HttpServerContext context);
}
