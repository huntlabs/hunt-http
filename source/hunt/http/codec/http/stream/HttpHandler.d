module hunt.http.codec.http.stream.HttpHandler;

import hunt.http.codec.http.stream.HttpOutputStream;
import hunt.http.codec.http.stream.HttpConnection;

import hunt.http.codec.http.model.MetaData;

import hunt.util.functional;
import hunt.container.ByteBuffer;

alias Request = MetaData.Request;
alias Response = MetaData.Response;

interface HttpHandler {

    bool content(ByteBuffer item, MetaData.Request request, MetaData.Response response,
                    HttpOutputStream output,
                    HttpConnection connection);

    bool contentComplete(MetaData.Request request, MetaData.Response response,
                            HttpOutputStream output,
                            HttpConnection connection);

    bool headerComplete(MetaData.Request request, MetaData.Response response,
                           HttpOutputStream output,
                           HttpConnection connection);

    bool messageComplete(MetaData.Request request, MetaData.Response response,
                            HttpOutputStream output,
                            HttpConnection connection);

    void badMessage(int status, string reason, MetaData.Request request, MetaData.Response response,
                    HttpOutputStream output, HttpConnection connection);

    void earlyEOF(MetaData.Request request, MetaData.Response response,
                  HttpOutputStream output,
                  HttpConnection connection);

}


class HttpHandlerAdapter : HttpHandler {

    protected Func4!(Request, Response, HttpOutputStream, HttpConnection, bool) _headerComplete;
    protected Func5!(ByteBuffer, Request, Response, HttpOutputStream, HttpConnection, bool) _content;
    protected Func4!(Request, Response, HttpOutputStream, HttpConnection, bool) _contentComplete;
    protected Func4!(Request, Response, HttpOutputStream, HttpConnection, bool) _messageComplete;
    protected Action6!(int, string, Request, Response, HttpOutputStream, HttpConnection) _badMessage;
    protected Action4!(Request, Response, HttpOutputStream, HttpConnection) _earlyEOF;

    override
    bool headerComplete(Request request, Response response,
                                    HttpOutputStream output,
                                    HttpConnection connection) {
        if (_headerComplete !is null) {
            return _headerComplete(request, response, output, connection);
        } else {
            return false;
        }
    }

    override
    bool content(ByteBuffer item, Request request, Response response,
                            HttpOutputStream output,
                            HttpConnection connection) {
        if (_content !is null) {
            return _content(item, request, response, output, connection);
        } else {
            return false;
        }
    }

    override
    bool contentComplete(MetaData.Request request, MetaData.Response response,
                                    HttpOutputStream output,
                                    HttpConnection connection) {
        if (_contentComplete !is null) {
            return _contentComplete(request, response, output, connection);
        } else {
            return false;
        }
    }


    override
    bool messageComplete(Request request, Response response,
                                    HttpOutputStream output,
                                    HttpConnection connection) {
        if (_messageComplete !is null) {
            return _messageComplete(request, response, output, connection);
        } else {
            return true;
        }
    }

    override
    void badMessage(int status, string reason, Request request, Response response,
                            HttpOutputStream output,
                            HttpConnection connection) {
        if (_badMessage !is null) {
            _badMessage(status, reason, request, response, output, connection);
        }
    }

    override
    void earlyEOF(Request request, Response response, HttpOutputStream output, HttpConnection connection) {
        if (_earlyEOF !is null) {
            _earlyEOF(request, response, output, connection);
        }
    }

}
