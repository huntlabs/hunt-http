module hunt.http.client.http.HTTP2ClientResponseHandler;

import hunt.http.client.http.ClientHTTPHandler;
import hunt.http.client.http.HTTPClientConnection;

import hunt.http.codec.http.frame;
import hunt.http.codec.http.model.HttpStatus;
import hunt.http.codec.http.model.MetaData;
import hunt.http.codec.http.stream.AbstractHTTP2OutputStream;
import hunt.http.codec.http.stream.DataFrameHandler;
import hunt.http.codec.http.stream.HTTPOutputStream;
import hunt.http.codec.http.stream.Stream;

import hunt.container.LinkedList;

import hunt.util.common;
import hunt.util.exception;
import hunt.util.functional;
import hunt.util.concurrent.Promise;
import kiss.logger;

import std.conv;
import std.string;

alias Request = MetaData.Request;

class HTTP2ClientResponseHandler : Stream.Listener.Adapter { //  , Runnable

    enum string OUTPUT_STREAM_KEY = "_outputStream";
    enum string RESPONSE_KEY = "_response";
    enum string RUN_TASK = "_runTask";

    private Request request;
    private ClientHTTPHandler handler;
    private HTTPClientConnection connection;
    private LinkedList!(ReceivedFrame) receivedFrames; // = new LinkedList!()();

    this(Request request, ClientHTTPHandler handler, HTTPClientConnection connection) {
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
        HTTPOutputStream output = getOutputStream(stream);
        if (output !is null) { // the stream is created completely
            run();
        } else {
            stream.setAttribute(RUN_TASK, this);
        }
    }

    private void onReceivedFrame(ReceivedFrame receivedFrame) {
        Stream stream = receivedFrame.getStream();
        HTTPOutputStream output = getOutputStream(stream);

        switch (receivedFrame.getFrame().getType()) {
            case FrameType.HEADERS: {
                HeadersFrame headersFrame = cast(HeadersFrame) receivedFrame.getFrame();
                if (headersFrame.getMetaData() is null) {
                    throw new IllegalArgumentException("the stream " ~ stream.getId().to!string() ~ " received a null meta data");
                }

                if (headersFrame.getMetaData().isResponse()) {
                    MetaData.Response response = cast(MetaData.Response) headersFrame.getMetaData();

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
                        MetaData.Response response = getResponse(stream);

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
                MetaData.Response response = getResponse(stream);

                DataFrameHandler.handleDataFrame(dataFrame, callback, request, response, output, connection, handler);
            }
            break;

            default: break;
        }
    }

    override
    void onReset(Stream stream, ResetFrame frame) {
        // writeln("Client received reset frame: " ~ stream ~ ", " ~ frame);
        HTTPOutputStream output = getOutputStream(stream);
        MetaData.Response response = getResponse(stream);

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

    private HTTPOutputStream getOutputStream(Stream stream) {
        return cast(HTTPOutputStream) stream.getAttribute(OUTPUT_STREAM_KEY);
    }

    private MetaData.Response getResponse(Stream stream) {
        return cast(MetaData.Response) stream.getAttribute(RESPONSE_KEY);
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

    static class ClientHttp2OutputStream : AbstractHTTP2OutputStream {

        private Stream stream;

        this(MetaData info, Stream stream) {
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

        private Request request;
        private Promise!(HTTPOutputStream) promise;

        this(Request request, Promise!(HTTPOutputStream) promise) {
            this.request = request;
            this.promise = promise;
        }

        void succeeded(Stream stream) {
            version(HuntDebugMode) {
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
