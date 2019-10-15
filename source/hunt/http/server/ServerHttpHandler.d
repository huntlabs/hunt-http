module hunt.http.server.ServerHttpHandler;

import hunt.http.server.HttpServerConnection;

import hunt.http.codec.http.model.MetaData;
import hunt.http.HttpConnection;
import hunt.http.codec.http.stream.HttpHandler;
import hunt.http.codec.http.stream.HttpOutputStream;
import hunt.http.codec.http.stream.HttpTunnelConnection;

import hunt.Functions;

import hunt.collection.ByteBuffer;

/**
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

alias ServerHttpHandlerAdapter = AbstractServerHttpHandler;

class AbstractServerHttpHandler : AbstractHttpHandler, ServerHttpHandler {

    protected Action1!HttpConnection _acceptConnection;
    protected Func4!(HttpRequest, HttpResponse, HttpOutputStream, HttpConnection, bool) _accept100Continue;
    protected Func4!(HttpRequest, HttpResponse, HttpOutputStream, HttpServerConnection, bool) _acceptHttpTunnelConnection;

    AbstractServerHttpHandler headerComplete(
            Func4!(HttpRequest, HttpResponse, HttpOutputStream, HttpConnection, bool) h) {
        this._headerComplete = h;
        return this;
    }

    AbstractServerHttpHandler messageComplete(
            Func4!(HttpRequest, HttpResponse, HttpOutputStream, HttpConnection, bool) m) {
        this._messageComplete = m;
        return this;
    }

    AbstractServerHttpHandler content(
            Func5!(ByteBuffer, HttpRequest, HttpResponse, HttpOutputStream, HttpConnection, bool) c) {
        this._content = c;
        return this;
    }

    AbstractServerHttpHandler contentComplete(
            Func4!(HttpRequest, HttpResponse, HttpOutputStream, HttpConnection, bool) c) {
        this._contentComplete = c;
        return this;
    }

    AbstractServerHttpHandler badMessage(
            Action6!(int, string, HttpRequest, HttpResponse, HttpOutputStream, HttpConnection) b) {
        this._badMessage = b;
        return this;
    }

    AbstractServerHttpHandler earlyEOF(
            Action4!(HttpRequest, HttpResponse, HttpOutputStream, HttpConnection) e) {
        this._earlyEOF = e;
        return this;
    }

    AbstractServerHttpHandler acceptConnection(Action1!HttpConnection c) {
        this._acceptConnection = c;
        return this;
    }

    AbstractServerHttpHandler accept100Continue(
            Func4!(HttpRequest, HttpResponse, HttpOutputStream, HttpConnection, bool) a) {
        this._accept100Continue = a;
        return this;
    }

    AbstractServerHttpHandler acceptHttpTunnelConnection(
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
