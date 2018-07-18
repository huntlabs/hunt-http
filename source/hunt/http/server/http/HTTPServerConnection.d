module hunt.http.server.http.HTTPServerConnection;

import hunt.http.codec.http.stream.HTTPConnection;
import hunt.http.codec.http.stream.HTTPTunnelConnection;
import hunt.util.concurrent.Promise;
import hunt.util.concurrent.CompletableFuture;


interface HTTPServerConnection : HTTPConnection { //  

    void upgradeHTTPTunnel(Promise!HTTPTunnelConnection promise);

    CompletableFuture!HTTPTunnelConnection upgradeHTTPTunnel();

}
