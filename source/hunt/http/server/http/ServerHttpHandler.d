module hunt.http.server.http.ServerHttpHandler;

import hunt.http.server.http.HttpServerConnection;

import hunt.http.codec.http.model.MetaData;
import hunt.http.codec.http.stream.HttpConnection;
import hunt.http.codec.http.stream.HttpHandler;
import hunt.http.codec.http.stream.HttpOutputStream;
import hunt.http.codec.http.stream.HttpTunnelConnection;

import hunt.util.functional;

import hunt.container.ByteBuffer;

/**
*/
interface ServerHttpHandler : HttpHandler {

    void acceptConnection(HttpConnection connection);

    bool accept100Continue(MetaData.Request request, MetaData.Response response,
                              HttpOutputStream output,
                              HttpConnection connection);

    bool acceptHttpTunnelConnection(MetaData.Request request, MetaData.Response response,
                                       HttpOutputStream output,
                                       HttpServerConnection connection);

}


class ServerHttpHandlerAdapter : HttpHandlerAdapter ,ServerHttpHandler {

    protected Action1!HttpConnection _acceptConnection;
    protected Func4!(Request, Response, HttpOutputStream, HttpConnection, bool) _accept100Continue;
    protected Func4!(Request, Response, HttpOutputStream, HttpServerConnection, bool) _acceptHttpTunnelConnection;

    ServerHttpHandlerAdapter headerComplete(
            Func4!(Request, Response, HttpOutputStream, HttpConnection, bool) h) {
        this._headerComplete = h;
        return this;
    }

    ServerHttpHandlerAdapter messageComplete(
            Func4!(Request, Response, HttpOutputStream, HttpConnection, bool) m) {
        this._messageComplete = m;
        return this;
    }

    ServerHttpHandlerAdapter content(
            Func5!(ByteBuffer, Request, Response, HttpOutputStream, HttpConnection, bool) c) {
        this._content = c;
        return this;
    }

    ServerHttpHandlerAdapter contentComplete(
            Func4!(Request, Response, HttpOutputStream, HttpConnection, bool) c) {
        this._contentComplete = c;
        return this;
    }

    ServerHttpHandlerAdapter badMessage(
            Action6!(int, string, Request, Response, HttpOutputStream, HttpConnection) b) {
        this._badMessage = b;
        return this;
    }

    ServerHttpHandlerAdapter earlyEOF(
            Action4!(Request, Response, HttpOutputStream, HttpConnection) e) {
        this._earlyEOF = e;
        return this;
    }

    ServerHttpHandlerAdapter acceptConnection(Action1!HttpConnection c) {
        this._acceptConnection = c;
        return this;
    }

    ServerHttpHandlerAdapter accept100Continue(
            Func4!(Request, Response, HttpOutputStream, HttpConnection, bool) a) {
        this._accept100Continue = a;
        return this;
    }

    ServerHttpHandlerAdapter acceptHttpTunnelConnection(
            Func4!(Request, Response, HttpOutputStream, HttpServerConnection, bool) a) {
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
    bool accept100Continue(Request request, Response response, HttpOutputStream output,
                                        HttpConnection connection) {
        if (_accept100Continue !is null) {
            return _accept100Continue(request, response, output, connection);
        } else {
            return false;
        }
    }

    override
    bool acceptHttpTunnelConnection(MetaData.Request request, MetaData.Response response,
                                                HttpOutputStream output,
                                                HttpServerConnection connection) {
        if (_acceptHttpTunnelConnection != null) {
            return _acceptHttpTunnelConnection(request, response, output, connection);
        } else {
            return true;
        }
    }

}
