module hunt.http.client.HttpClientOptions;

import hunt.http.HttpOptions;
import hunt.net.TcpSslOptions;
import hunt.net.NetClientOptions;

class HttpClientOptions : HttpOptions {

    this() {
        this(new NetClientOptions());
    }

    this(NetClientOptions options) {
        super(options);
    }

    override NetClientOptions getTcpConfiguration() {
        return cast(NetClientOptions)super.getTcpConfiguration;
    }
}