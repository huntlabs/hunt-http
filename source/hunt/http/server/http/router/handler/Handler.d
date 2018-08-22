module hunt.http.server.http.router.handler.Handler;

import hunt.http.server.http.router.RoutingContext;

/**
 * 
 */
interface Handler {

    void handle(RoutingContext routingContext);

}



alias RoutingHandler =  void delegate(RoutingContext routingContext);