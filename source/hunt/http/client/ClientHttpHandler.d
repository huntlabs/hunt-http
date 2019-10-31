module hunt.http.client.ClientHttpHandler;

import hunt.http.HttpRequest;
import hunt.http.HttpResponse;
import hunt.http.HttpConnection;
import hunt.http.codec.http.stream.HttpHandler;
import hunt.http.HttpOutputStream;

import hunt.Functions;
import hunt.util.Common;
import hunt.collection.ByteBuffer;

/**
*/
interface ClientHttpHandler : HttpHandler {

    void continueToSendData(HttpRequest request, HttpResponse response,
            HttpOutputStream output, HttpConnection connection);
}

/**
*/
class AbstractClientHttpHandler : AbstractHttpHandler, ClientHttpHandler {

    protected Action4!(HttpRequest, HttpResponse, HttpOutputStream, HttpConnection) _continueToSendData;

    AbstractClientHttpHandler headerComplete(Func4!(HttpRequest, HttpResponse,
            HttpOutputStream, HttpConnection, bool) h) {
        this._headerComplete = h;
        return this;
    }

    AbstractClientHttpHandler content(Func5!(ByteBuffer, HttpRequest, HttpResponse,
            HttpOutputStream, HttpConnection, bool) c) {
        this._content = c;
        return this;
    }

    AbstractClientHttpHandler contentComplete(Func4!(HttpRequest, HttpResponse,
            HttpOutputStream, HttpConnection, bool) c) {
        this._contentComplete = c;
        return this;
    }

    AbstractClientHttpHandler messageComplete(Func4!(HttpRequest, HttpResponse,
            HttpOutputStream, HttpConnection, bool) m) {
        this._messageComplete = m;
        return this;
    }

    AbstractClientHttpHandler badMessage(Action6!(int, string, HttpRequest,
            HttpResponse, HttpOutputStream, HttpConnection) b) {
        this._badMessage = b;
        return this;
    }

    AbstractClientHttpHandler earlyEOF(Action4!(HttpRequest, HttpResponse,
            HttpOutputStream, HttpConnection) e) {
        this._earlyEOF = e;
        return this;
    }

    AbstractClientHttpHandler continueToSendData(Action4!(HttpRequest, HttpResponse,
            HttpOutputStream, HttpConnection) c) {
        this._continueToSendData = c;
        return this;
    }

    override void continueToSendData(HttpRequest request, HttpResponse response,
            HttpOutputStream output, HttpConnection connection) {
        if (_continueToSendData != null) {
            _continueToSendData(request, response, output, connection);
        }
    }

}
