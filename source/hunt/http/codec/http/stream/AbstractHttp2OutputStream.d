module hunt.http.codec.http.stream.AbstractHttp2OutputStream;

import hunt.http.codec.http.stream.HttpOutputStream;
import hunt.http.codec.http.stream.Stream;

import hunt.http.codec.http.frame;
import hunt.http.HttpFields;
import hunt.http.HttpHeader;
import hunt.http.HttpMetaData;
import hunt.http.HttpRequest;
import hunt.http.HttpVersion;

import hunt.collection.ByteBuffer;
import hunt.collection.LinkedList;

import hunt.Functions;
import hunt.Exceptions;
import hunt.util.Common;

import hunt.logging;

/**
 * 
 */
abstract class AbstractHttp2OutputStream : HttpOutputStream , Callback 
{

    private long size;
    private bool isWriting;
    private LinkedList!Frame frames;
    private bool noContent = true;

    this(HttpMetaData metaData, bool clientMode) {
        super(metaData, clientMode);
        frames = new LinkedList!Frame();
    }

    override
    void write(ByteBuffer data) {
        Stream stream = getStream();
        assert(!closed, "The stream " ~ stream.toString() ~ " output is closed.");

        noContent = false;
        commit();
        writeFrame(new DataFrame(stream.getId(), data, isLastFrame(data)));
    }

    override
    void commit() {
        if (committed || closed) {
            return;
        }

        HeadersFrame headersFrame = new HeadersFrame(getStream().getId(), metaData, null, noContent);
        version(HUNT_DEBUG) {
            tracef("http2 output stream %s commits the header frame %s", getStream().toString(), headersFrame.toString());
        }
        writeFrame(headersFrame);
        committed = true;
    }

    override
    void close() {
        if (closed) {
            return;
        }

        commit();
        if (isChunked()) {
            // Optional.ofNullable(metaData.getTrailerSupplier())
            //         .map(Supplier::get)
            //         .ifPresent(trailer -> {
            //             HttpMetaData metaData = new HttpMetaData(HttpVersion.HTTP_1_1, trailer);
            //             HeadersFrame trailerFrame = new HeadersFrame(getStream().getId(), metaData, null, true);
            //             frames.offer(trailerFrame);
            //         });

            Supplier!HttpFields supplier= metaData.getTrailerSupplier();
            if(supplier !is null)
            {
                HttpFields trailer = supplier();
                if(trailer !is null)
                {
                    HttpMetaData metaData = new HttpMetaData(HttpVersion.HTTP_1_1, trailer);
                        HeadersFrame trailerFrame = new HeadersFrame(getStream().getId(), metaData, null, true);
                        frames.offer(trailerFrame);
                }
            }


            DisconnectFrame disconnectFrame = new DisconnectFrame();
            frames.offer(disconnectFrame);
            if (!isWriting) {
                succeeded();
            }
        }
        closed = true;
    }

    void writeFrame(Frame frame) {
        if (isChunked()) {
            frames.offer(frame);
            if (!isWriting) {
                succeeded();
            }
        } else {
            if (isWriting) {
                frames.offer(frame);
            } else {
                _writeFrame(frame);
            }
        }
    }

    override
    void succeeded() {
        if (isChunked()) {
            if (frames.size() > 2) {
                _writeFrame(frames.poll());
            } else if (frames.size() == 2) {
                Frame frame = frames.getLast();
                if (frame.getType() == FrameType.DISCONNECT) {
                    Frame lastFrame = frames.poll();
                    frames.clear();
                    switch (lastFrame.getType()) {
                        case FrameType.DATA: {
                            DataFrame dataFrame = cast(DataFrame) lastFrame;
                            if (dataFrame.isEndStream()) {
                                _writeFrame(dataFrame);
                            } else {
                                DataFrame lastDataFrame = new DataFrame(dataFrame.getStreamId(), dataFrame.getData(), true);
                                _writeFrame(lastDataFrame);
                            }
                        }
                        break;
                        case FrameType.HEADERS: {
                            HeadersFrame headersFrame = cast(HeadersFrame) lastFrame;
                            if (headersFrame.isEndStream()) {
                                _writeFrame(headersFrame);
                            } else {
                                HeadersFrame lastHeadersFrame = new HeadersFrame(headersFrame.getStreamId(),
                                        headersFrame.getMetaData(), headersFrame.getPriority(), true);
                                _writeFrame(lastHeadersFrame);
                            }
                        }
                        break;
                        default:
                            throw new IllegalStateException("The last frame must be data frame or header frame");
                    }
                } else {
                    _writeFrame(frames.poll());
                }
            } else if (frames.size() == 1) {
                Frame frame = frames.getLast();
                if (isLastFrame(frame)) {
                    _writeFrame(frames.poll());
                } else {
                    isWriting = false;
                }
            } else {
                isWriting = false;
            }
        } else {
            Frame frame = frames.poll();
            if (frame !is null) {
                _writeFrame(frame);
            } else {
                isWriting = false;
            }
        }
    }

    bool isLastFrame(Frame frame) {
        switch (frame.getType()) {
            case FrameType.HEADERS:
                HeadersFrame headersFrame = cast(HeadersFrame) frame;
                return headersFrame.isEndStream();
            case FrameType.DATA:
                DataFrame dataFrame = cast(DataFrame) frame;
                return dataFrame.isEndStream();
            default: break;
        }
        return false;
    }

    // override
    void failed(Exception x) {
        frames.clear();
        getStream().getSession().close(cast(int)ErrorCode.INTERNAL_ERROR, "Write frame failure", Callback.NOOP);
        closed = true;
        errorf("Write frame failure", x);
    }

    bool isNonBlocking() {
        return false;
    }

    protected void _writeFrame(Frame frame) {
        isWriting = true;
        switch (frame.getType()) {
            case FrameType.HEADERS: {
                HeadersFrame headersFrame = cast(HeadersFrame) frame;
                closed = headersFrame.isEndStream();
                getStream().headers(headersFrame, this);
                break;
            }
            case FrameType.DATA: {
                DataFrame dataFrame = cast(DataFrame) frame;
                closed = dataFrame.isEndStream();
                getStream().data(dataFrame, this);
                break;
            }

            default: break;
        }
    }

    protected bool isLastFrame(ByteBuffer data) {
        long contentLength = getContentLength();
        if (contentLength < 0) {
            return false;
        } else {
            size += data.remaining();
            tracef("http2 output size: %s, content length: %s", size, contentLength);
            return size >= contentLength;
        }
    }

    protected long getContentLength() {
        return metaData.getFields().getLongField(HttpHeader.CONTENT_LENGTH.asString());
    }

    bool isNoContent() {
        return noContent;
    }

    protected bool isChunked() {
        return !noContent && getContentLength() < 0;
    }

    abstract protected Stream getStream();

}
