module hunt.http.client.Http2ClientResponseHandler;

import hunt.http.client.ClientHttpHandler;
import hunt.http.client.HttpClientConnection;

import hunt.http.codec.http.frame;
import hunt.http.codec.http.stream.AbstractHttp2OutputStream;
import hunt.http.codec.http.stream.DataFrameHandler;
import hunt.http.HttpOutputStream;
import hunt.http.codec.http.stream.Stream;

import hunt.http.HttpMetaData;
import hunt.http.HttpStatus;
import hunt.http.HttpRequest;
import hunt.http.HttpResponse;

import hunt.collection.LinkedList;
import hunt.concurrency.Promise;
import hunt.logging;
import hunt.Exceptions;
import hunt.util.Common;

import std.conv;
import std.string;


class Http2ClientResponseHandler : Stream.Listener.Adapter { //  , Runnable

    enum string OUTPUT_STREAM_KEY = "_outputStream";
    enum string RESPONSE_KEY = "_response";
    enum string RUN_TASK = "_runTask";

    private HttpRequest request;
    private ClientHttpHandler handler;
    private HttpClientConnection connection;
    private LinkedList!(ReceivedFrame) receivedFrames; // = new LinkedList!()();

    this(HttpRequest request, ClientHttpHandler handler, HttpClientConnection connection) {
        this.request = request;
        this.handler = handler;
        this.connection = connection;
        receivedFrames = new LinkedList!(ReceivedFrame)();
    }

    override
    void onHeaders(Stream stream, HeadersFrame headersFrame) {
        // Wait the stream is created.
        receivedFrames.add(new ReceivedFrame(stream, headersFrame, Callback.NOOP));
        onFrames(stream);
    }

    override
    void onData(Stream stream, DataFrame dataFrame, Callback callback) {
        receivedFrames.add(new ReceivedFrame(stream, dataFrame, callback));
        onFrames(stream);
    }

    // override
    void run() {
        ReceivedFrame receivedFrame;
        while ((receivedFrame = receivedFrames.poll()) !is null) {
            onReceivedFrame(receivedFrame);
        }
    }

    private void onFrames(Stream stream) {
        HttpOutputStream output = getOutputStream(stream);
        if (output !is null) { // the stream is created completely
            run();
        } else {
            stream.setAttribute(RUN_TASK, this);
        }
    }

    private void onReceivedFrame(ReceivedFrame receivedFrame) {
        Stream stream = receivedFrame.getStream();
        HttpOutputStream output = getOutputStream(stream);

        switch (receivedFrame.getFrame().getType()) {
            case FrameType.HEADERS: {
                HeadersFrame headersFrame = cast(HeadersFrame) receivedFrame.getFrame();
                if (headersFrame.getMetaData() is null) {
                    throw new IllegalArgumentException("the stream " ~ stream.getId().to!string() ~ " received a null meta data");
                }

                if (headersFrame.getMetaData().isResponse()) {
                    HttpResponse response = cast(HttpResponse) headersFrame.getMetaData();

                    if (response.getStatus() == HttpStatus.CONTINUE_100) {
                        handler.continueToSendData(request, response, output, connection);
                    } else {
                        stream.setAttribute(RESPONSE_KEY, response);
                        handler.headerComplete(request, response, output, connection);
                        if (headersFrame.isEndStream()) {
                            handler.messageComplete(request, response, output, connection);
                        }
                    }
                } else {
                    if (headersFrame.isEndStream()) {
                        HttpResponse response = getResponse(stream);

                        response.setTrailerSupplier(() => headersFrame.getMetaData().getFields());
                        handler.contentComplete(request, response, output, connection);
                        handler.messageComplete(request, response, output, connection);
                    } else {
                        throw new IllegalArgumentException("the stream " ~ stream.getId().to!string() ~ " received illegal meta data");
                    }
                }
            }
            break;

            case FrameType.DATA: {
                DataFrame dataFrame = cast(DataFrame) receivedFrame.getFrame();
                Callback callback = receivedFrame.getCallback();
                HttpResponse response = getResponse(stream);

                DataFrameHandler.handleDataFrame(dataFrame, callback, request, response, output, connection, handler);
            }
            break;

            default: break;
        }
    }

    override
    void onReset(Stream stream, ResetFrame frame) {
        // writeln("Client received reset frame: " ~ stream ~ ", " ~ frame);
        HttpOutputStream output = getOutputStream(stream);
        HttpResponse response = getResponse(stream);

        int errorCode = frame.getError();
        string reason = isValidErrorCode(errorCode) ? (cast(ErrorCode)errorCode).to!string().toLower() : "error=" ~ errorCode.to!string();
        int status = HttpStatus.INTERNAL_SERVER_ERROR_500;

        if(errorCode == ErrorCode.PROTOCOL_ERROR)
            status = HttpStatus.BAD_REQUEST_400;

        // if (isValidErrorCode(errorCode)) {
        //     switch (errorCode) {
        //         case ErrorCode.PROTOCOL_ERROR:
        //             status = HttpStatus.BAD_REQUEST_400;
        //             break;
        //         default:
        //             status = HttpStatus.INTERNAL_SERVER_ERROR_500;
        //             break;
        //     }
        // }
        handler.badMessage(status, reason, request, response, output, connection);
    }

    private HttpOutputStream getOutputStream(Stream stream) {
        return cast(HttpOutputStream) stream.getAttribute(OUTPUT_STREAM_KEY);
    }

    private HttpResponse getResponse(Stream stream) {
        return cast(HttpResponse) stream.getAttribute(RESPONSE_KEY);
    }

    static class ReceivedFrame {
        private Stream stream;
        private Frame frame;
        private Callback callback;

        this(Stream stream, Frame frame, Callback callback) {
            this.stream = stream;
            this.frame = frame;
            this.callback = callback;
        }

        Stream getStream() {
            return stream;
        }

        Frame getFrame() {
            return frame;
        }

        Callback getCallback() {
            return callback;
        }
    }

    static class ClientHttp2OutputStream : AbstractHttp2OutputStream {

        private Stream stream;

        this(HttpMetaData info, Stream stream) {
            super(info, true);
            committed = true;
            this.stream = stream;
        }

        override
        protected Stream getStream() {
            return stream;
        }
    }

    static class ClientStreamPromise : Promise!(Stream) {

        private HttpRequest request;
        private Promise!(HttpOutputStream) promise;

        this(HttpRequest request, Promise!(HttpOutputStream) promise) {
            this.request = request;
            this.promise = promise;
        }

        void succeeded(Stream stream) {
            version(HUNT_DEBUG) {
                tracef("create a new stream %s", stream.getId());
            }

            ClientHttp2OutputStream output = new ClientHttp2OutputStream(request, stream);
            stream.setAttribute(OUTPUT_STREAM_KEY, output);

            Runnable r = cast(Runnable) stream.getAttribute(RUN_TASK);
            if(r !is null)
                r.run();

            // Optional.ofNullable(cast(Runnable) stream.getAttribute(RUN_TASK))
            //         .ifPresent(Runnable::run);
            promise.succeeded(output);
        }

        void failed(Exception x) {
            promise.failed(x);
            errorf("client creates stream unsuccessfully", x);
        }

        string id() { return "undefined"; }

    }
}
