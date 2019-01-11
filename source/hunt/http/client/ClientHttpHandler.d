module hunt.http.client.ClientHttpHandler;

import hunt.http.codec.http.model.MetaData;
import hunt.http.codec.http.stream.HttpConnection;
import hunt.http.codec.http.stream.HttpHandler;
import hunt.http.codec.http.stream.HttpOutputStream;

import hunt.Functions;
import hunt.util.Common;
import hunt.collection.ByteBuffer;

alias Request = HttpRequest;
alias Response = HttpResponse;

interface ClientHttpHandler : HttpHandler {

    void continueToSendData(HttpRequest request, HttpResponse response, HttpOutputStream output,
                            HttpConnection connection);

    static class Adapter : HttpHandlerAdapter, ClientHttpHandler {

        protected Action4!(Request, Response, HttpOutputStream, HttpConnection) _continueToSendData;

        ClientHttpHandler.Adapter headerComplete(
                Func4!(Request, Response, HttpOutputStream, HttpConnection, bool) h) {
            this._headerComplete = h;
            return this;
        }

        ClientHttpHandler.Adapter content(
                Func5!(ByteBuffer, Request, Response, HttpOutputStream, HttpConnection, bool) c) {
            this._content = c;
            return this;
        }

        ClientHttpHandler.Adapter contentComplete(
                Func4!(Request, Response, HttpOutputStream, HttpConnection, bool) c) {
            this._contentComplete = c;
            return this;
        }

        ClientHttpHandler.Adapter messageComplete(
                Func4!(Request, Response, HttpOutputStream, HttpConnection, bool) m) {
            this._messageComplete = m;
            return this;
        }

        ClientHttpHandler.Adapter badMessage(
                Action6!(int, string, Request, Response, HttpOutputStream, HttpConnection) b) {
            this._badMessage = b;
            return this;
        }

        ClientHttpHandler.Adapter earlyEOF(
                Action4!(Request, Response, HttpOutputStream, HttpConnection) e) {
            this._earlyEOF = e;
            return this;
        }

        ClientHttpHandler.Adapter continueToSendData(
                Action4!(Request, Response, HttpOutputStream, HttpConnection) c) {
            this._continueToSendData = c;
            return this;
        }

        override
        void continueToSendData(Request request, Response response, HttpOutputStream output,
                                       HttpConnection connection) {
            if (_continueToSendData != null) {
                _continueToSendData(request, response, output, connection);
            }
        }

    }
}
