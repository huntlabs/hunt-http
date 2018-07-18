module hunt.http.server.http.ServerHTTPHandler;

import hunt.http.server.http.HTTPServerConnection;

import hunt.http.codec.http.model.MetaData;
import hunt.http.codec.http.stream.HTTPConnection;
import hunt.http.codec.http.stream.HTTPHandler;
import hunt.http.codec.http.stream.HTTPOutputStream;
import hunt.http.codec.http.stream.HTTPTunnelConnection;

import hunt.util.functional;

import hunt.container.ByteBuffer;

/**
*/
interface ServerHTTPHandler : HTTPHandler {

    void acceptConnection(HTTPConnection connection);

    bool accept100Continue(MetaData.Request request, MetaData.Response response,
                              HTTPOutputStream output,
                              HTTPConnection connection);

    bool acceptHTTPTunnelConnection(MetaData.Request request, MetaData.Response response,
                                       HTTPOutputStream output,
                                       HTTPServerConnection connection);

}


class ServerHTTPHandlerAdapter : HTTPHandlerAdapter ,ServerHTTPHandler {

    protected Action1!HTTPConnection _acceptConnection;
    protected Func4!(Request, Response, HTTPOutputStream, HTTPConnection, bool) _accept100Continue;
    protected Func4!(Request, Response, HTTPOutputStream, HTTPServerConnection, bool) _acceptHTTPTunnelConnection;

    ServerHTTPHandlerAdapter headerComplete(
            Func4!(Request, Response, HTTPOutputStream, HTTPConnection, bool) h) {
        this._headerComplete = h;
        return this;
    }

    ServerHTTPHandlerAdapter messageComplete(
            Func4!(Request, Response, HTTPOutputStream, HTTPConnection, bool) m) {
        this._messageComplete = m;
        return this;
    }

    ServerHTTPHandlerAdapter content(
            Func5!(ByteBuffer, Request, Response, HTTPOutputStream, HTTPConnection, bool) c) {
        this._content = c;
        return this;
    }

    ServerHTTPHandlerAdapter contentComplete(
            Func4!(Request, Response, HTTPOutputStream, HTTPConnection, bool) c) {
        this._contentComplete = c;
        return this;
    }

    ServerHTTPHandlerAdapter badMessage(
            Action6!(int, string, Request, Response, HTTPOutputStream, HTTPConnection) b) {
        this._badMessage = b;
        return this;
    }

    ServerHTTPHandlerAdapter earlyEOF(
            Action4!(Request, Response, HTTPOutputStream, HTTPConnection) e) {
        this._earlyEOF = e;
        return this;
    }

    ServerHTTPHandlerAdapter acceptConnection(Action1!HTTPConnection c) {
        this._acceptConnection = c;
        return this;
    }

    ServerHTTPHandlerAdapter accept100Continue(
            Func4!(Request, Response, HTTPOutputStream, HTTPConnection, bool) a) {
        this._accept100Continue = a;
        return this;
    }

    ServerHTTPHandlerAdapter acceptHTTPTunnelConnection(
            Func4!(Request, Response, HTTPOutputStream, HTTPServerConnection, bool) a) {
        this._acceptHTTPTunnelConnection = a;
        return this;
    }

    override
    void acceptConnection(HTTPConnection connection) {
        if (_acceptConnection != null) {
            _acceptConnection(connection);
        }
    }

    override
    bool accept100Continue(Request request, Response response, HTTPOutputStream output,
                                        HTTPConnection connection) {
        if (_accept100Continue !is null) {
            return _accept100Continue(request, response, output, connection);
        } else {
            return false;
        }
    }

    override
    bool acceptHTTPTunnelConnection(MetaData.Request request, MetaData.Response response,
                                                HTTPOutputStream output,
                                                HTTPServerConnection connection) {
        if (_acceptHTTPTunnelConnection != null) {
            return _acceptHTTPTunnelConnection(request, response, output, connection);
        } else {
            return true;
        }
    }

}
