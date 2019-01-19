module hunt.http.client.Http1ClientResponseHandler;

import hunt.http.client.ClientHttpHandler;
import hunt.http.client.Http1ClientConnection;
import hunt.http.client.HttpClientResponse;

import hunt.http.codec.http.decode.HttpParser;
import hunt.http.codec.http.model;
import hunt.http.codec.http.stream.HttpOutputStream;

import hunt.collection.ByteBuffer;
import hunt.io;
import hunt.logging;
import hunt.text.Common;

import hunt.trace.Constrants;
import hunt.trace.Plugin;
import hunt.trace.Span;

import std.string : icmp;
import std.conv;

alias ResponseHandler = HttpParser.ResponseHandler;

/**
*/
class Http1ClientResponseHandler : ResponseHandler {
    package(hunt.http.client)  Http1ClientConnection connection;
    package(hunt.http.client)  HttpResponse response;
    package(hunt.http.client)  HttpRequest request;
    package(hunt.http.client) HttpOutputStream outputStream;
    protected ClientHttpHandler clientHttpHandler;
    protected HttpFields trailer;

    private Span _span;
    private string[string] tags;

    this(ClientHttpHandler clientHttpHandler) {
        this.clientHttpHandler = clientHttpHandler;

    }

    package(hunt.http.client) void onReady() {
        if(request !is null)
            initializeTracer(request);
    }

    private void initializeTracer(HttpRequest request) {
        HttpURI uri = request.getURI();
        tags[HTTP_HOST] = uri.getHost();
        tags[HTTP_URL] = uri.getPathQuery();
        tags[HTTP_PATH] = uri.getPath();
        tags[HTTP_REQUEST_SIZE] = request.getContentLength().to!string();
        tags[HTTP_METHOD] = request.getMethod();

        _span = traceSpanBefore(request.getURI().getPath());
        if(_span !is null) {
            request.getFields().put("b3", _span.defaultId());
        }
    }

    override
    final bool startResponse(HttpVersion ver, int status, string reason) {
        version(HUNT_DEBUG) {
            tracef("client received the response line, %s, %s, %s", ver, status, reason);
        }

        if (status == HttpStatus.CONTINUE_100 && HttpStatus.Code.CONTINUE.getMessage().equalsIgnoreCase(reason)) {
            clientHttpHandler.continueToSendData(request, response, outputStream, connection);
            version(HUNT_DEBUG) {
                tracef("client received 100 continue, current parser state is %s", connection.getParser().getState());
            }
            return true;
        } else {
            response = new HttpClientResponse(ver, status, reason);
            return false;
        }
    }

    override
    final void parsedHeader(HttpField field) {
        response.getFields().add(field);
    }

    override
    final int getHeaderCacheSize() {
        return 1024;
    }

    override
    final bool headerComplete() {
        return clientHttpHandler.headerComplete(request, response, outputStream, connection);
    }

    override
    final bool content(ByteBuffer item) {
        return clientHttpHandler.content(item, request, response, outputStream, connection);
    }

    override
    bool contentComplete() {
        return clientHttpHandler.contentComplete(request, response, outputStream, connection);
    }

    override
    void parsedTrailer(HttpField field) {
        if (trailer is null) {
            trailer = new HttpFields();
            response.setTrailerSupplier(() => trailer);
        }
        trailer.add(field);
    }

    private void endTraceSpan(string error) {
        if(_span !is null) {
            tags[HTTP_STATUS_CODE] = to!string(response.getStatus());
            tags[HTTP_RESPONSE_SIZE] = to!string(response.getContentLength());

            traceSpanAfter(_span , tags , error);
        }
    }

    protected bool http1MessageComplete() {
        try {
            endTraceSpan("");
            return clientHttpHandler.messageComplete(request, response, outputStream, connection);
        } finally {
            string requestConnectionValue = request.getFields().get(HttpHeader.CONNECTION);
            string responseConnectionValue = response.getFields().get(HttpHeader.CONNECTION);

            connection.getParser().reset();

            HttpVersion httpVersion = response.getHttpVersion();

            if(httpVersion == HttpVersion.HTTP_1_0) {
                if (icmp("keep-alive", requestConnectionValue)
                        && icmp("keep-alive", responseConnectionValue)) {
                    tracef("the client %s connection is persistent", response.getHttpVersion());
                } else {
                    IOUtils.close(connection);
                } 
            } else if (httpVersion == HttpVersion.HTTP_1_1){ // the persistent connection is default in HTTP 1.1
                if (icmp("close", requestConnectionValue)
                        || icmp("close", responseConnectionValue)) {
                    IOUtils.close(connection);
                } else {
                    tracef("the client %s connection is persistent", response.getHttpVersion());
                }
            }

        }
    }

    override
    final bool messageComplete() {
        bool success = connection.upgradeProtocolComplete(request, response);
        if (success) {
            tracef("client upgraded protocol successfully");
        }
        return http1MessageComplete();
    }

    
    void badMessage(BadMessageException failure) {
        badMessage(failure.getCode(), failure.getReason());
    }

    override
    final void badMessage(int status, string reason) {
        clientHttpHandler.badMessage(status, reason, request, response, outputStream, connection);
    }

    override
    void earlyEOF() {
        clientHttpHandler.earlyEOF(request, response, outputStream, connection);
    }

}
