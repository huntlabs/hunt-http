module hunt.http.server.HttpServerOptions;

import hunt.http.HttpOptions;
import hunt.net.TcpSslOptions;
import hunt.net.NetServerOptions;

class HttpServerOptions : HttpOptions {

    this() {
        this(new NetServerOptions());
    }

    this(NetServerOptions options) {
        super(options);
    }

    override NetServerOptions getTcpConfiguration() {
        return cast(NetServerOptions)super.getTcpConfiguration;
    }
}