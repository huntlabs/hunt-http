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
                Func4!(Request, Response, HTTPOutputStream, HTTPConnection, bool) headerComplete) {
            this.headerComplete = headerComplete;
            return this;
        }

        ClientHTTPHandler.Adapter content(
                Func5!(ByteBuffer, Request, Response, HTTPOutputStream, HTTPConnection, bool) content) {
            this.content = content;
            return this;
        }

        ClientHTTPHandler.Adapter contentComplete(
                Func4!(Request, Response, HTTPOutputStream, HTTPConnection, bool) contentComplete) {
            this.contentComplete = contentComplete;
            return this;
        }

        ClientHTTPHandler.Adapter messageComplete(
                Func4!(Request, Response, HTTPOutputStream, HTTPConnection, bool) messageComplete) {
            this.messageComplete = messageComplete;
            return this;
        }

        ClientHTTPHandler.Adapter badMessage(
                Action6!(int, string, Request, Response, HTTPOutputStream, HTTPConnection) badMessage) {
            this.badMessage = badMessage;
            return this;
        }

        ClientHTTPHandler.Adapter earlyEOF(
                Action4!(Request, Response, HTTPOutputStream, HTTPConnection) earlyEOF) {
            this.earlyEOF = earlyEOF;
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
