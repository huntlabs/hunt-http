module hunt.http.server.HttpServerConnection;

import hunt.http.HttpConnection;
import hunt.http.codec.http.stream.HttpTunnelConnection;
import hunt.concurrency.Promise;
import hunt.concurrency.CompletableFuture;

/**
*/
interface HttpServerConnection : HttpConnection { 

    void upgradeHttpTunnel(Promise!HttpTunnelConnection promise);

    CompletableFuture!HttpTunnelConnection upgradeHttpTunnel();

}
