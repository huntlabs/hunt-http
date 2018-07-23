module hunt.http.client.http.ClientHTTPHandler;

import hunt.http.codec.http.model.MetaData;

import hunt.http.codec.http.stream.HTTPConnection;
import hunt.http.codec.http.stream.HTTPHandler;
import hunt.http.codec.http.stream.HTTPOutputStream;


import hunt.util.functional;
import hunt.container.ByteBuffer;

alias Request = MetaData.Request;
alias Response = MetaData.Response;

interface ClientHTTPHandler : HTTPHandler {

    void continueToSendData(MetaData.Request request, MetaData.Response response, HTTPOutputStream output,
                            HTTPConnection connection);

    static class Adapter : HTTPHandlerAdapter, ClientHTTPHandler {

        protected Action4!(Request, Response, HTTPOutputStream, HTTPConnection) _continueToSendData;

        ClientHTTPHandler.Adapter headerComplete(
                Func4!(Request, Response, HTTPOutputStream, HTTPConnection, bool) h) {
            this._headerComplete = h;
            return this;
        }

        ClientHTTPHandler.Adapter content(
                Func5!(ByteBuffer, Request, Response, HTTPOutputStream, HTTPConnection, bool) c) {
            this._content = c;
            return this;
        }

        ClientHTTPHandler.Adapter contentComplete(
                Func4!(Request, Response, HTTPOutputStream, HTTPConnection, bool) c) {
            this._contentComplete = c;
            return this;
        }

        ClientHTTPHandler.Adapter messageComplete(
                Func4!(Request, Response, HTTPOutputStream, HTTPConnection, bool) m) {
            this._messageComplete = m;
            return this;
        }

        ClientHTTPHandler.Adapter badMessage(
                Action6!(int, string, Request, Response, HTTPOutputStream, HTTPConnection) b) {
            this._badMessage = b;
            return this;
        }

        ClientHTTPHandler.Adapter earlyEOF(
                Action4!(Request, Response, HTTPOutputStream, HTTPConnection) e) {
            this._earlyEOF = e;
            return this;
        }

        ClientHTTPHandler.Adapter continueToSendData(
                Action4!(Request, Response, HTTPOutputStream, HTTPConnection) c) {
            this._continueToSendData = c;
            return this;
        }

        override
        void continueToSendData(Request request, Response response, HTTPOutputStream output,
                                       HTTPConnection connection) {
            if (_continueToSendData != null) {
                _continueToSendData(request, response, output, connection);
            }
        }

    }
}
