module hunt.http.router.RoutingHandler;

import hunt.http.router.RoutingContext;

alias RoutingHandler =  void delegate(RoutingContext routingContext);

alias Handler = IRoutingHandler;

/**
 * 
 */
interface IRoutingHandler {
    void handle(RoutingContext routingContext);
}
