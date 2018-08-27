module hunt.http.client.http.HTTP1ClientResponseHandler;

import hunt.http.client.http.ClientHTTPHandler;
import hunt.http.client.http.HTTP1ClientConnection;
import hunt.http.client.http.HTTPClientResponse;


import hunt.http.codec.http.decode.HttpParser;
import hunt.http.codec.http.model;
import hunt.http.codec.http.stream.HTTPOutputStream;

import hunt.util.string;
import hunt.io;
import hunt.logging;

import hunt.container.ByteBuffer;

alias ResponseHandler = HttpParser.ResponseHandler;

/**
*/
class HTTP1ClientResponseHandler : ResponseHandler {
    package(hunt.http.client.http)  HTTP1ClientConnection connection;
    package(hunt.http.client.http)  MetaData.Response response;
    package(hunt.http.client.http)  MetaData.Request request;
    package(hunt.http.client.http) HTTPOutputStream outputStream;
    protected ClientHTTPHandler clientHTTPHandler;
    protected HttpFields trailer;

    this(ClientHTTPHandler clientHTTPHandler) {
        this.clientHTTPHandler = clientHTTPHandler;
    }

    override
    final bool startResponse(HttpVersion ver, int status, string reason) {
        version(HuntDebugMode) {
            tracef("client received the response line, %s, %s, %s", ver, status, reason);
        }

        if (status == HttpStatus.CONTINUE_100 && HttpStatus.Code.CONTINUE.getMessage().equalsIgnoreCase(reason)) {
            clientHTTPHandler.continueToSendData(request, response, outputStream, connection);
            version(HuntDebugMode) {
                tracef("client received 100 continue, current parser state is %s", connection.getParser().getState());
            }
            return true;
        } else {
            response = new HTTPClientResponse(ver, status, reason);
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
        return clientHTTPHandler.headerComplete(request, response, outputStream, connection);
    }

    override
    final bool content(ByteBuffer item) {
        return clientHTTPHandler.content(item, request, response, outputStream, connection);
    }

    override
    bool contentComplete() {
        return clientHTTPHandler.contentComplete(request, response, outputStream, connection);
    }

    override
    void parsedTrailer(HttpField field) {
        if (trailer is null) {
            trailer = new HttpFields();
            response.setTrailerSupplier(() => trailer);
        }
        trailer.add(field);
    }

    protected bool http1MessageComplete() {
        try {
            return clientHTTPHandler.messageComplete(request, response, outputStream, connection);
        } finally {
            string requestConnectionValue = request.getFields().get(HttpHeader.CONNECTION);
            string responseConnectionValue = response.getFields().get(HttpHeader.CONNECTION);

            connection.getParser().reset();

            HttpVersion httpVersion = response.getHttpVersion();

                if(httpVersion == HttpVersion.HTTP_1_0) {
                    if ("keep-alive".equalsIgnoreCase(requestConnectionValue)
                            && "keep-alive".equalsIgnoreCase(responseConnectionValue)) {
                        tracef("the client %s connection is persistent", response.getHttpVersion());
                    } else {
                        IO.close(connection);
                    }
                } else if (httpVersion == HttpVersion.HTTP_1_1){ // the persistent connection is default in HTTP 1.1
                    if ("close".equalsIgnoreCase(requestConnectionValue)
                            || "close".equalsIgnoreCase(responseConnectionValue)) {
                        IO.close(connection);
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
        clientHTTPHandler.badMessage(status, reason, request, response, outputStream, connection);
    }

    override
    void earlyEOF() {
        clientHTTPHandler.earlyEOF(request, response, outputStream, connection);
    }

}
