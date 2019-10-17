module hunt.http.router.RoutingHandler;

import hunt.http.router.RoutingContext;

alias RoutingHandler =  void delegate(RoutingContext routingContext);

deprecated("Using IRoutingHandler instead.")
alias Handler = IRoutingHandler;

/**
 * 
 */
interface IRoutingHandler {
    void handle(RoutingContext context);
}
