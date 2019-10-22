module hunt.http.routing.RequestAcceptor;

import hunt.http.server.HttpServerContext;

/**
 * 
 */
interface RequestAcceptor {
    void accept(HttpServerContext context);
}
