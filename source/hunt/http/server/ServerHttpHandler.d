module hunt.http.server.ServerHttpHandler;

import hunt.http.server.HttpServerConnection;
import hunt.http.server.HttpServerOptions;

import hunt.http.codec.http.stream.HttpHandler;
import hunt.http.HttpOutputStream;
import hunt.http.codec.http.stream.HttpTunnelConnection;

import hunt.http.HttpConnection;
import hunt.http.HttpRequest;
import hunt.http.HttpResponse;

import hunt.collection.ByteBuffer;
import hunt.Functions;


/**
 * 
 */
interface ServerHttpHandler : HttpHandler {

    void acceptConnection(HttpConnection connection);

    bool accept100Continue(HttpRequest request, HttpResponse response,
                              HttpOutputStream output,
                              HttpConnection connection);

    bool acceptHttpTunnelConnection(HttpRequest request, HttpResponse response,
                                       HttpOutputStream output,
                                       HttpServerConnection connection);

}

// deprecated("Using AbstractServerHttpHandler instead.")
// alias ServerHttpHandlerAdapter = AbstractServerHttpHandler;

/**
 * 
 */
class ServerHttpHandlerAdapter : AbstractHttpHandler, ServerHttpHandler {

    private HttpServerOptions _httpOptions;

    protected Action1!HttpConnection _acceptConnection;
    protected Func4!(HttpRequest, HttpResponse, HttpOutputStream, HttpConnection, bool) _accept100Continue;
    protected Func4!(HttpRequest, HttpResponse, HttpOutputStream, HttpServerConnection, bool) _acceptHttpTunnelConnection;

    this(HttpServerOptions options) {
        _httpOptions = options;
    }

    HttpServerOptions serverOptions() {
        return _httpOptions;
    }

    // FIXME: Needing refactor or cleanup -@zhangxueping at 2019-10-16T11:46:06+08:00
    // refactor to use HttpServerContext 
    ServerHttpHandlerAdapter headerComplete(
            Func4!(HttpRequest, HttpResponse, HttpOutputStream, HttpConnection, bool) h) {
        this._headerComplete = h;
        return this;
    }

    ServerHttpHandlerAdapter messageComplete(
            Func4!(HttpRequest, HttpResponse, HttpOutputStream, HttpConnection, bool) m) {
        this._messageComplete = m;
        return this;
    }

    ServerHttpHandlerAdapter content(
            Func5!(ByteBuffer, HttpRequest, HttpResponse, HttpOutputStream, HttpConnection, bool) c) {
        this._content = c;
        return this;
    }

    ServerHttpHandlerAdapter contentComplete(
            Func4!(HttpRequest, HttpResponse, HttpOutputStream, HttpConnection, bool) c) {
        this._contentComplete = c;
        return this;
    }

    ServerHttpHandlerAdapter badMessage(
            Action6!(int, string, HttpRequest, HttpResponse, HttpOutputStream, HttpConnection) b) {
        this._badMessage = b;
        return this;
    }

    ServerHttpHandlerAdapter earlyEOF(
            Action4!(HttpRequest, HttpResponse, HttpOutputStream, HttpConnection) e) {
        this._earlyEOF = e;
        return this;
    }

    ServerHttpHandlerAdapter acceptConnection(Action1!HttpConnection c) {
        this._acceptConnection = c;
        return this;
    }

    ServerHttpHandlerAdapter accept100Continue(
            Func4!(HttpRequest, HttpResponse, HttpOutputStream, HttpConnection, bool) a) {
        this._accept100Continue = a;
        return this;
    }

    ServerHttpHandlerAdapter acceptHttpTunnelConnection(
            Func4!(HttpRequest, HttpResponse, HttpOutputStream, HttpServerConnection, bool) a) {
        this._acceptHttpTunnelConnection = a;
        return this;
    }

    override
    void acceptConnection(HttpConnection connection) {
        if (_acceptConnection != null) {
            _acceptConnection(connection);
        }
    }

    override
    bool accept100Continue(HttpRequest request, HttpResponse response, HttpOutputStream output,
                                        HttpConnection connection) {
        if (_accept100Continue !is null) {
            return _accept100Continue(request, response, output, connection);
        } else {
            return false;
        }
    }

    override
    bool acceptHttpTunnelConnection(HttpRequest request, HttpResponse response,
                                                HttpOutputStream output,
                                                HttpServerConnection connection) {
        if (_acceptHttpTunnelConnection != null) {
            return _acceptHttpTunnelConnection(request, response, output, connection);
        } else {
            return true;
        }
    }

}
