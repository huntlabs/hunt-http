module hunt.http.server.http.router.RequestAcceptor;

import hunt.http.server.http.SimpleRequest;

/**
 * 
 */
interface RequestAcceptor {

    void accept(SimpleRequest request);

}
