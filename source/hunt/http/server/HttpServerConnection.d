module hunt.http.server.HttpServerConnection;

import hunt.http.codec.http.stream.HttpConnection;
import hunt.http.codec.http.stream.HttpTunnelConnection;
import hunt.util.concurrent.Promise;
import hunt.util.concurrent.CompletableFuture;


interface HttpServerConnection : HttpConnection { //  

    void upgradeHttpTunnel(Promise!HttpTunnelConnection promise);

    CompletableFuture!HttpTunnelConnection upgradeHttpTunnel();

}
