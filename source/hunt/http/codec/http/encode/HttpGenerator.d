module hunt.http.codec.http.encode.HttpGenerator;

import hunt.http.codec.http.model;
// import hunt.http.codec.http.model.HttpField;
// import hunt.http.codec.http.model.HttpFields;
// import hunt.http.codec.http.model.HttpMethod;
// import hunt.http.codec.http.model.HttpHeader;
// import hunt.http.codec.http.model.HttpTokens;
// import hunt.http.codec.http.model.HttpVersion;
// import hunt.http.codec.http.model.MetaData;
import hunt.http.codec.http.hpack.HpackEncoder;

import hunt.http.environment;
import hunt.collection;
import hunt.util.DateTime;
import hunt.Exceptions;
import hunt.Functions;
import hunt.logging;
import hunt.text.Common;
import hunt.text.StringBuilder;
import hunt.text.StringUtils;

import core.time;
import std.array;
import std.conv;
import std.format;
import std.string;


/**
 * HttpGenerator. Builds HTTP Messages.
 * <p>
 * If the system property "http.HttpGenerator.STRICT" is set
 * to true, then the generator will strictly pass on the exact strings received
 * from methods and header fields. Otherwise a fast case insensitive string
 * lookup is used that may alter the case and white space of some
 * methods/headers
 */
class HttpGenerator {
    // static bool __STRICT = bool.getBoolean("hunt.http.codec.http.encode.HttpGenerator.STRICT");

    private enum byte[] __colon_space = [':', ' '];
    __gshared HttpResponse CONTINUE_100_INFO;
    __gshared HttpResponse PROGRESS_102_INFO;
    __gshared HttpResponse RESPONSE_500_INFO;


    // states
    enum State {
        START, COMMITTED, COMPLETING, COMPLETING_1XX, END
    }

    enum Result {
        NEED_CHUNK,             // Need a small chunk buffer of CHUNK_SIZE
        NEED_INFO,              // Need the request/response metadata info
        NEED_HEADER,            // Need a buffer to build HTTP headers into
        NEED_CHUNK_TRAILER,     // Need a large chunk buffer for last chunk and trailers
        FLUSH,                  // The buffers previously generated should be flushed
        CONTINUE,               // Continue generating the message
        SHUTDOWN_OUT,           // Need EOF to be signaled
        DONE                    // Message generation complete
    }

    // other statics
    static int CHUNK_SIZE = 12;

    private State _state = State.START;
    private EndOfContent _endOfContent = EndOfContent.UNKNOWN_CONTENT;

    private long _contentPrepared = 0;
    private bool _noContentResponse = false;
    private bool _persistent = false;
    private Supplier!HttpFields _trailers = null;

    private int _send;
    private __gshared int SEND_SERVER = 0x01;
    private __gshared int SEND_XPOWEREDBY = 0x02;
    private __gshared bool[string] __assumedContentMethods; // = new ArrayTrie<>(8);

    shared static this() {
        __assumedContentMethods[HttpMethod.POST.asString()] = true;
        __assumedContentMethods[HttpMethod.PUT.asString()] = true;
        CONTINUE_100_INFO = new HttpResponse(HttpVersion.HTTP_1_1, 100, null, null, -1);
        PROGRESS_102_INFO = new HttpResponse(HttpVersion.HTTP_1_1, 102, null, null, -1);
        HttpFields hf = new HttpFields();
        hf.put(HttpHeader.CONNECTION, HttpHeaderValue.CLOSE);

        RESPONSE_500_INFO = new HttpResponse(HttpVersion.HTTP_1_1, HttpStatus.INTERNAL_SERVER_ERROR_500, null, hf, 0);
    }

    /* ------------------------------------------------------------------------------- */
    static void setVersion(string serverVersion) {
        SEND[SEND_SERVER] = StringUtils.getBytes("Server: " ~ serverVersion ~ "\015\012");
        SEND[SEND_XPOWEREDBY] = StringUtils.getBytes("X-Powered-By: " ~ serverVersion ~ "\015\012");
        SEND[SEND_SERVER | SEND_XPOWEREDBY] = StringUtils.getBytes("Server: " ~ serverVersion ~ 
            "\015\012X-Powered-By: " ~ serverVersion ~ "\015\012");
    }

    /* ------------------------------------------------------------------------------- */
    // data
    private bool _needCRLF = false;
    private MonoTime startTime;

    /* ------------------------------------------------------------------------------- */
    this() {
        this(false, false);
    }

    /* ------------------------------------------------------------------------------- */
    this(bool sendServerVersion, bool sendXPoweredBy) {
        _send = (sendServerVersion ? SEND_SERVER : 0) | (sendXPoweredBy ? SEND_XPOWEREDBY : 0);
    }

    /* ------------------------------------------------------------------------------- */
    void reset() {
        _state = State.START;
        _endOfContent = EndOfContent.UNKNOWN_CONTENT;
        _noContentResponse = false;
        _persistent = false;
        _contentPrepared = 0;
        _needCRLF = false;
        _trailers = null;
    }

    /* ------------------------------------------------------------ */
    State getState() {
        return _state;
    }

    /* ------------------------------------------------------------ */
    bool isState(State state) {
        return _state == state;
    }

    /* ------------------------------------------------------------ */
    bool isIdle() {
        return _state == State.START;
    }

    /* ------------------------------------------------------------ */
    bool isEnd() {
        return _state == State.END;
    }

    /* ------------------------------------------------------------ */
    bool isCommitted() {
        return _state >= State.COMMITTED;
    }

    /* ------------------------------------------------------------ */
    bool isChunking() {
        return _endOfContent == EndOfContent.CHUNKED_CONTENT;
    }

    /* ------------------------------------------------------------ */
    bool isNoContent() {
        return _noContentResponse;
    }

    /* ------------------------------------------------------------ */
    void setPersistent(bool persistent) {
        _persistent = persistent;
    }

    /* ------------------------------------------------------------ */

    /**
     * @return true if known to be persistent
     */
    bool isPersistent() {
        return _persistent;
    }

    /* ------------------------------------------------------------ */
    bool isWritten() {
        return _contentPrepared > 0;
    }

    /* ------------------------------------------------------------ */
    long getContentPrepared() {
        return _contentPrepared;
    }

    /* ------------------------------------------------------------ */
    void abort() {
        _persistent = false;
        _state = State.END;
        _endOfContent = EndOfContent.UNKNOWN_CONTENT;
    }

    /* ------------------------------------------------------------ */
    Result generateRequest(HttpRequest metaData, ByteBuffer header, 
        ByteBuffer chunk, ByteBuffer content, bool last) {

        switch (_state) {
            case State.START: {
                if (metaData is null)
                    return Result.NEED_INFO;

                if (header is null)
                    return Result.NEED_HEADER;

                // If we have not been told our persistence, set the default
                // if (_persistent == null) 
                {
                    // HttpVersion v = HttpVersion.HTTP_1_0;
                    _persistent = metaData.getHttpVersion() >  HttpVersion.HTTP_1_0;
                    if (!_persistent && HttpMethod.CONNECT.isSame(metaData.getMethod()))
                        _persistent = true;
                }

                // prepare the header
                int pos = BufferUtils.flipToFill(header);
                try {
                    // generate ResponseLine
                    generateRequestLine(metaData, header);

                    if (metaData.getHttpVersion() == HttpVersion.HTTP_0_9)
                        throw new BadMessageException(HttpStatus.INTERNAL_SERVER_ERROR_500, "HTTP/0.9 not supported");

                    generateHeaders(metaData, header, content, last);
                    enum string continueString = HttpHeaderValue.CONTINUE.asString();
                    bool expect100 = metaData.getFields().contains(HttpHeader.EXPECT, continueString);

                    if (expect100) {
                        _state = State.COMMITTED;
                    } else {
                        // handle the content.
                        int len = BufferUtils.length(content);
                        if (len > 0) {
                            _contentPrepared += len;
                            if (isChunking())
                                prepareChunk(header, len);
                        }
                        _state = last ? State.COMPLETING : State.COMMITTED;
                    }

                    return Result.FLUSH;
                } catch (BadMessageException e) {
                    throw e;
                } catch (BufferOverflowException e) {
                    throw new BadMessageException(HttpStatus.INTERNAL_SERVER_ERROR_500, "Request header too large", e);
                } catch (Exception e) {
                    throw new BadMessageException(HttpStatus.INTERNAL_SERVER_ERROR_500, cast(string)e.message(), e);
                } finally {
                    BufferUtils.flipToFlush(header, pos);
                }
            }

            case State.COMMITTED: {
                return committed(chunk, content, last);
            }

            case State.COMPLETING: {
                return completing(chunk, content);
            }

            case State.END:
                if (BufferUtils.hasContent(content)) {
                    version(HUNT_DEBUG) {
                        tracef("discarding content in COMPLETING");
                    }
                    BufferUtils.clear(content);
                }
                return Result.DONE;

            default:
                throw new IllegalStateException("");
        }
    }

    private Result committed(ByteBuffer chunk, ByteBuffer content, bool last) {
        int len = BufferUtils.length(content);

        // handle the content.
        if (len > 0) {
            if (isChunking()) {
                if (chunk is null)
                    return Result.NEED_CHUNK;
                BufferUtils.clearToFill(chunk);
                prepareChunk(chunk, len);
                BufferUtils.flipToFlush(chunk, 0);
            }
            _contentPrepared += len;
        }

        if (last) {
            _state = State.COMPLETING;
            return len > 0 ? Result.FLUSH : Result.CONTINUE;
        }
        return len > 0 ? Result.FLUSH : Result.DONE;
    }

    private Result completing(ByteBuffer chunk, ByteBuffer content) {
        version(HUNT_METRIC) {
            scope(exit) {
                Duration timeElapsed = MonoTime.currTime - startTime;
                warningf("generating completed in: %d microseconds", 
                    timeElapsed.total!(TimeUnit.Microsecond)());
            }
        }

        if (BufferUtils.hasContent(content)) {
            version(HUNT_DEBUG)
                tracef("discarding content in COMPLETING");
            BufferUtils.clear(content);
        }

        if (isChunking()) {
            if (_trailers != null) {
                // Do we need a chunk buffer?
                if (chunk is null || chunk.capacity() <= CHUNK_SIZE)
                    return Result.NEED_CHUNK_TRAILER;

                HttpFields trailers = _trailers();

                if (trailers !is null) {
                    // Write the last chunk
                    BufferUtils.clearToFill(chunk);
                    generateTrailers(chunk, trailers);
                    BufferUtils.flipToFlush(chunk, 0);
                    _endOfContent = EndOfContent.UNKNOWN_CONTENT;
                    return Result.FLUSH;
                }
            }

            // Do we need a chunk buffer?
            if (chunk is null)
                return Result.NEED_CHUNK;

            // Write the last chunk
            BufferUtils.clearToFill(chunk);
            prepareChunk(chunk, 0);
            BufferUtils.flipToFlush(chunk, 0);
            _endOfContent = EndOfContent.UNKNOWN_CONTENT;
            return Result.FLUSH;
        }

        _state = State.END;
        return _persistent ? Result.DONE : Result.SHUTDOWN_OUT;

    }

    /* ------------------------------------------------------------ */
    Result generateResponse(HttpResponse metaData, bool head, ByteBuffer header, 
        ByteBuffer chunk, ByteBuffer content, bool last){
        switch (_state) {
            case State.START: {
                if (metaData is null)
                    return Result.NEED_INFO;
                HttpVersion ver = metaData.getHttpVersion();
                if (ver == HttpVersion.Null) {
                    throw new BadMessageException(HttpStatus.INTERNAL_SERVER_ERROR_500, "No version");
                }
                
                version(HUNT_METRIC) {
                    startTime = MonoTime.currTime;
                    debug info("generating response...");
                }
                switch (ver.getVersion()) {
                    case HttpVersion.HTTP_1_0.getVersion():
                        _persistent = false;
                        break;

                    case HttpVersion.HTTP_1_1.getVersion():
                        _persistent = true;
                        break;

                    default:
                        _persistent = false;
                        _endOfContent = EndOfContent.EOF_CONTENT;
                        if (BufferUtils.hasContent(content))
                            _contentPrepared += content.remaining();
                        _state = last ? State.COMPLETING : State.COMMITTED;
                        return Result.FLUSH;
                }

                // Do we need a response header
                if (header is null)
                    return Result.NEED_HEADER;

                // prepare the header
                int pos = BufferUtils.flipToFill(header);
                try {
                    // generate ResponseLine
                    generateResponseLine(metaData, header);

                    // Handle 1xx and no content responses
                    int status = metaData.getStatus();
                    if (status >= 100 && status < 200) {
                        _noContentResponse = true;

                        if (status != HttpStatus.SWITCHING_PROTOCOLS_101) {
                            header.put(HttpTokens.CRLF);
                            _state = State.COMPLETING_1XX;
                            return Result.FLUSH;
                        }
                    } else if (status == HttpStatus.NO_CONTENT_204 || status == HttpStatus.NOT_MODIFIED_304) {
                        _noContentResponse = true;
                    }

                    generateHeaders(metaData, header, content, last);

                    // handle the content.
                    int len = BufferUtils.length(content);
                    if (len > 0) {
                        _contentPrepared += len;
                        if (isChunking() && !head)
                            prepareChunk(header, len);
                    }
                    _state = last ? State.COMPLETING : State.COMMITTED;
                } catch (BadMessageException e) {
                    throw e;
                } catch (BufferOverflowException e) {
                    throw new BadMessageException(HttpStatus.INTERNAL_SERVER_ERROR_500, "Request header too large", e);
                } catch (Exception e) {
                    throw new BadMessageException(HttpStatus.INTERNAL_SERVER_ERROR_500, cast(string)e.message(), e);
                } finally {
                    BufferUtils.flipToFlush(header, pos);
                }

                version(HUNT_METRIC) {
                    // debug infof("_state: %s", _state);
                    if(_state == State.COMMITTED) {
                        Duration timeElapsed = MonoTime.currTime - startTime;
                        warningf("comitted in: %d microseconds", 
                            timeElapsed.total!(TimeUnit.Microsecond)());
                    }
                }
                return Result.FLUSH;
            }

            case State.COMMITTED: {
                return committed(chunk, content, last);
            }

            case State.COMPLETING_1XX: {
                reset();
                return Result.DONE;
            }

            case State.COMPLETING: {
                return completing(chunk, content);
            }

            case State.END:
                info("444444");
                if (BufferUtils.hasContent(content)) {
                    version(HUNT_DEBUG) {
                        tracef("discarding content in COMPLETING");
                    }
                    BufferUtils.clear(content);
                }
                return Result.DONE;

            default: {
                string msg = format("bad generator state: %s", _state);
                warning(msg);
                throw new IllegalStateException(msg);
            }
        }
    }

    /* ------------------------------------------------------------ */
    private void prepareChunk(ByteBuffer chunk, int remaining) {
        // if we need CRLF add this to header
        if (_needCRLF)
            BufferUtils.putCRLF(chunk);

        // Add the chunk size to the header
        if (remaining > 0) {
            BufferUtils.putHexInt(chunk, remaining);
            BufferUtils.putCRLF(chunk);
            _needCRLF = true;
        } else {
            chunk.put(LAST_CHUNK);
            _needCRLF = false;
        }
    }

    /* ------------------------------------------------------------ */
    private void generateTrailers(ByteBuffer buffer, HttpFields trailer) {
        // if we need CRLF add this to header
        if (_needCRLF)
            BufferUtils.putCRLF(buffer);

        // Add the chunk size to the header
        buffer.put(ZERO_CHUNK);

        int n = trailer.size();
        for (int f = 0; f < n; f++) {
            HttpField field = trailer.getField(f);
            string v = field.getValue();
            if (v == null || v.length == 0)
                continue; // rfc7230 does not allow no value

            putTo(field, buffer);
        }

        BufferUtils.putCRLF(buffer);
    }

    /* ------------------------------------------------------------ */
    private void generateRequestLine(HttpRequest request, ByteBuffer header) {
        header.put(StringUtils.getBytes(request.getMethod()));
        header.put(cast(byte) ' ');
        header.put(StringUtils.getBytes(request.getURIString()));
        header.put(cast(byte) ' ');
        header.put(request.getHttpVersion().toBytes());
        header.put(HttpTokens.CRLF);
    }

    /* ------------------------------------------------------------ */
    private void generateResponseLine(HttpResponse response, ByteBuffer header) {
        // Look for prepared response line
        int status = response.getStatus();
        // version(HUNT_HTTP_DEBUG) {
        //     infof("status code: %d", status);
        // }
        PreparedResponse preprepared = status < __preprepared.length ? __preprepared[status] : null;
        string reason = response.getReason();
        if (preprepared !is null) {
            if (reason.empty()) {
                header.put(preprepared._responseLine);
            } else {
                header.put(preprepared._schemeCode);
                header.put(getReasonBytes(reason));
                header.put(HttpTokens.CRLF);
            }
        } else { // generate response line
            header.put(HTTP_1_1_SPACE);
            header.put(cast(byte) ('0' + status / 100));
            header.put(cast(byte) ('0' + (status % 100) / 10));
            header.put(cast(byte) ('0' + (status % 10)));
            header.put(cast(byte) ' ');
            if (reason.empty()) {
                header.put(cast(byte) ('0' + status / 100));
                header.put(cast(byte) ('0' + (status % 100) / 10));
                header.put(cast(byte) ('0' + (status % 10)));
            } else {
                header.put(getReasonBytes(reason));
            }
            header.put(HttpTokens.CRLF);
        }
    }

    /* ------------------------------------------------------------ */
    private byte[] getReasonBytes(string reason) {
        if (reason.length > 1024)
            reason = reason.substring(0, 1024);
        byte[] _bytes = StringUtils.getBytes(reason);

        for (size_t i = _bytes.length; i-- > 0; )
            if (_bytes[i] == '\r' || _bytes[i] == '\n')
                _bytes[i] = '?';
        return _bytes;
    }

    /* ------------------------------------------------------------ */
    private void generateHeaders(MetaData metaData, ByteBuffer header, ByteBuffer content, bool last) {
        HttpRequest request = cast(HttpRequest) metaData;
        HttpResponse response = cast(HttpResponse) metaData;

        version(HUNT_HTTP_DEBUG) {
            tracef("Header fields:\n%s", metaData.getFields().toString());
            tracef("generateHeaders %s, last=%s, content=%s", metaData.toString(), 
                last, BufferUtils.toDetailString(content));
        }
        
        version(HUNT_HTTP_DEBUG_MORE) {
            tracef("content: %s", cast(string)content.getRemaining());
        }

        // default field values
        int send = _send;
        HttpField transfer_encoding = null;
        bool http11 = metaData.getHttpVersion() == HttpVersion.HTTP_1_1;
        bool close = false;
        _trailers = http11 ? metaData.getTrailerSupplier() : null;
        bool chunked_hint = _trailers != null;
        bool content_type = false;
        long content_length = metaData.getContentLength();
        bool content_length_field = false;

        // Generate fields
        HttpFields fields = metaData.getFields();
        if (fields !is null) {
            for (int f = 0; f < fields.size(); f++) {
                HttpField field = fields.getField(f);
                string v = field.getValue();
                if (v == null || v.length == 0)
                    continue; // rfc7230 does not allow no value

                HttpHeader h = field.getHeader();
                if (h == HttpHeader.Null) {
                    putTo(field, header);
                }
                else {
                        if(h == HttpHeader.CONTENT_LENGTH) {
                            if (content_length < 0)
                                content_length = field.getLongValue();
                            else if (content_length != field.getLongValue()) {
                                throw new BadMessageException(HttpStatus.INTERNAL_SERVER_ERROR_500, 
                                    format("Incorrect Content-Length %d!=%d", 
                                        content_length, field.getLongValue()));
                            }
                            content_length_field = true;
                        }
                        else if(h == HttpHeader.CONTENT_TYPE) {
                            // write the field to the header
                            content_type = true;
                            putTo(field, header);
                        }
                        else if(h == HttpHeader.TRANSFER_ENCODING) {
                            if (http11) {
                                // Don't add yet, treat this only as a hint that there is content
                                // with a preference to chunk if we can
                                transfer_encoding = field;
                                chunked_hint = field.contains(HttpHeaderValue.CHUNKED.asString());
                            }
                        }
                        else if(h == HttpHeader.CONNECTION) {
                            putTo(field, header);
                            if (field.contains(HttpHeaderValue.CLOSE.asString())) {
                                close = true;
                                _persistent = false;
                            }

                            if (!http11 && field.contains(HttpHeaderValue.KEEP_ALIVE.asString())) {
                                _persistent = true;
                            }
                        }
                        else if(h == HttpHeader.SERVER) {
                            send = send & ~SEND_SERVER;
                            putTo(field, header);
                        }
                        else
                            putTo(field, header);
                }
            }
        }

        // Can we work out the content length?
        if (last && content_length < 0 && _trailers == null)
            content_length = _contentPrepared + BufferUtils.length(content);

        // Calculate how to end _content and connection, _content length and transfer encoding
        // settings from http://tools.ietf.org/html/rfc7230#section-3.3.3
        bool assumed_content_request = false;
        if(request !is null) {
            string currentMethold = request.getMethod();
            bool* itemPtr = currentMethold in __assumedContentMethods;
            if(itemPtr !is null )
                assumed_content_request = *itemPtr;
        }
        
        bool assumed_content = assumed_content_request || content_type || chunked_hint;
        bool nocontent_request = request !is null && content_length <= 0 && !assumed_content;

        // If the message is known not to have content
        if (_noContentResponse || nocontent_request) {
            // We don't need to indicate a body length
            _endOfContent = EndOfContent.NO_CONTENT;

            // But it is an error if there actually is content
            if (_contentPrepared > 0 || content_length > 0) {
                if (_contentPrepared == 0 && last) {
                    // TODO discard content for backward compatibility with 9.3 releases
                    // TODO review if it is still needed in 9.4 or can we just throw.
                    content.clear();
                    content_length = 0;
                } else
                    throw new BadMessageException(HttpStatus.INTERNAL_SERVER_ERROR_500, "Content for no content response");
            }
        }
        // Else if we are HTTP/1.1 and the content length is unknown and we are either persistent
        // or it is a request with content (which cannot EOF) or the app has requested chunking
        else if (http11 && content_length < 0 && (_persistent || assumed_content_request || chunked_hint)) {
            // we use chunking
            _endOfContent = EndOfContent.CHUNKED_CONTENT;

            // try to use user supplied encoding as it may have other values.
            if (transfer_encoding is null)
                header.put(TRANSFER_ENCODING_CHUNKED);
            else if (transfer_encoding.toString().endsWith(HttpHeaderValue.CHUNKED.toString())) {
                putTo(transfer_encoding, header);
                transfer_encoding = null;
            } else if (!chunked_hint) {
                putTo(new HttpField(HttpHeader.TRANSFER_ENCODING, transfer_encoding.getValue() ~ ",chunked"), header);
                transfer_encoding = null;
            } else
                throw new BadMessageException(HttpStatus.INTERNAL_SERVER_ERROR_500, "Bad Transfer-Encoding");
        }
        // Else if we known the content length and are a request or a persistent response, 
        else if (content_length >= 0 && (request !is null || _persistent)) {
            // Use the content length 
            _endOfContent = EndOfContent.CONTENT_LENGTH;
            putContentLength(header, content_length);
        }
        // Else if we are a response
        else if (response !is null) {
            // We must use EOF - even if we were trying to be persistent
            _endOfContent = EndOfContent.EOF_CONTENT;
            _persistent = false;
            if (content_length >= 0 && (content_length > 0 || assumed_content || content_length_field))
                putContentLength(header, content_length);

            if (http11 && !close)
                header.put(CONNECTION_CLOSE);
        }
        // Else we must be a request
        else {
            // with no way to indicate body length
            throw new BadMessageException(HttpStatus.INTERNAL_SERVER_ERROR_500, "Unknown content length for request");
        }

        // version(HUNT_DEBUG) {
        //     trace("End Of Content: ", _endOfContent.to!string());
        // }
        // Add transfer encoding if it is not chunking
        if (transfer_encoding !is null) {
            if (chunked_hint) {
                string v = transfer_encoding.getValue();
                int c = cast(int)v.lastIndexOf(',');
                if (c > 0 && v.lastIndexOf(HttpHeaderValue.CHUNKED.toString(), c) > c)
                    putTo(new HttpField(HttpHeader.TRANSFER_ENCODING, v.substring(0, c).strip()), header);
            } else {
                putTo(transfer_encoding, header);
            }
        }

        // Send server?
        int status = response !is null ? response.getStatus() : -1;
        if (status > 199)
            header.put(SEND[send]);

        // end the header.
        header.put(HttpTokens.CRLF);
    }

    /* ------------------------------------------------------------------------------- */
    private static void putContentLength(ByteBuffer header, long contentLength) {
        if (contentLength == 0)
            header.put(CONTENT_LENGTH_0);
        else {
            header.put(HttpHeader.CONTENT_LENGTH.getBytesColonSpace());
            BufferUtils.putDecLong(header, contentLength);
            header.put(HttpTokens.CRLF);
        }
    }

    /* ------------------------------------------------------------------------------- */
    static byte[] getReasonBuffer(int code) {
        PreparedResponse status = code < __preprepared.length ? __preprepared[code] : null;
        if (status !is null)
            return status._reason;
        return null;
    }

    /* ------------------------------------------------------------------------------- */
    override
    string toString() {
        return format("%s@%x{s=%s}", typeof(this).stringof,
                toHash(),
                _state);
    }

    /* ------------------------------------------------------------------------------- */
    /* ------------------------------------------------------------------------------- */
    /* ------------------------------------------------------------------------------- */
    // common _content
    private enum byte[] ZERO_CHUNK = ['0', '\015', '\012'];
    private enum byte[] LAST_CHUNK = ['0', '\015', '\012', '\015', '\012'];
    private __gshared byte[] CONTENT_LENGTH_0; // = StringUtils.getBytes("Content-Length: 0\015\012");
    private __gshared byte[] CONNECTION_CLOSE; // = StringUtils.getBytes("Connection: close\015\012");
    private __gshared byte[] HTTP_1_1_SPACE; // = StringUtils.getBytes(HttpVersion.HTTP_1_1.toString() ~ " ");
    private __gshared byte[] TRANSFER_ENCODING_CHUNKED; // = StringUtils.getBytes("Transfer-Encoding: chunked\015\012");
    private __gshared byte[][] SEND;

    /* ------------------------------------------------------------------------------- */
    /* ------------------------------------------------------------------------------- */
    /* ------------------------------------------------------------------------------- */
    // Build cache of response lines for status
    private static class PreparedResponse {
        byte[] _reason;
        byte[] _schemeCode;
        byte[] _responseLine;
    }

    private __gshared PreparedResponse[] __preprepared; // = new PreparedResponse[HttpStatus.MAX_CODE + 1];

    shared static this() {
        CONTENT_LENGTH_0 = StringUtils.getBytes("Content-Length: 0\015\012");
        CONNECTION_CLOSE = StringUtils.getBytes("Connection: close\015\012");
        HTTP_1_1_SPACE = StringUtils.getBytes(HttpVersion.HTTP_1_1.toString() ~ " ");
        TRANSFER_ENCODING_CHUNKED = StringUtils.getBytes("Transfer-Encoding: chunked\015\012");
        SEND = [
            new byte[0],
            StringUtils.getBytes("Server: Hunt(" ~ Version ~ ")\015\012"),
            StringUtils.getBytes("X-Powered-By: Hunt(" ~ Version ~ ")\015\012"),
            StringUtils.getBytes("Server: Hunt(" ~ Version ~ ")\015\012X-Powered-By: Hunt(" ~ Version ~ ")\015\012")
        ];
        
        __preprepared = new PreparedResponse[HttpStatus.MAX_CODE + 1];

        string versionString = HttpVersion.HTTP_1_1.toString();
        int versionLength = cast(int)versionString.length;

        for (int i = 0; i < __preprepared.length; i++) {
            HttpStatus.Code code = HttpStatus.getCode(i);
            if (code == HttpStatus.Code.Null)
                continue;
            string reason = code.getMessage();
            byte[] line = new byte[versionLength + 5 + reason.length + 2];
            line[0 .. versionLength] = cast(byte[])versionString[0 .. $];
            // HttpVersion.HTTP_1_1.toBuffer().get(line, 0, versionLength);

            line[versionLength + 0] = ' ';
            line[versionLength + 1] = cast(byte) ('0' + i / 100);
            line[versionLength + 2] = cast(byte)('0' + (i % 100) / 10);
            line[versionLength + 3] = cast(byte)('0' + (i % 10));
            line[versionLength + 4] = ' ';
            for (int j = 0; j < reason.length; j++)
                line[versionLength + 5 + j] = cast(byte)reason.charAt(j);
            line[versionLength + 5 + reason.length] = HttpTokens.CARRIAGE_RETURN;
            line[versionLength + 6 + reason.length] = HttpTokens.LINE_FEED;

            __preprepared[i] = new PreparedResponse();
            __preprepared[i]._schemeCode = line[0 .. versionLength + 5].dup;
            __preprepared[i]._reason = line[versionLength + 5 .. line.length - 2];
            __preprepared[i]._responseLine = line;
        }
    }

    private static void putSanitisedName(string s, ByteBuffer buffer) {
        int l = cast(int)s.length;
        for (int i = 0; i < l; i++) {
            char c = s[i];

            if (c < 0 || c > 0xff || c == '\r' || c == '\n' || c == ':')
                buffer.put(cast(byte) '?');
            else
                buffer.put(cast(byte) (0xff & c));
        }
    }

    private static void putSanitisedValue(string s, ByteBuffer buffer) {
        int l = cast(int)s.length;
        for (int i = 0; i < l; i++) {
            char c = s[i];

            if (c < 0 || c > 0xff || c == '\r' || c == '\n')
                buffer.put(cast(byte) ' ');
            else
                buffer.put(cast(byte) (0xff & c));
        }
    }

    static void putTo(HttpField field, ByteBuffer bufferInFillMode) {
        if (typeid(field) == typeid(PreEncodedHttpField)) {
            (cast(PreEncodedHttpField) field).putTo(bufferInFillMode, HttpVersion.HTTP_1_0);
        } else {
            HttpHeader header = field.getHeader();
            if (header != HttpHeader.Null) {
                bufferInFillMode.put(header.getBytesColonSpace());
                putSanitisedValue(field.getValue(), bufferInFillMode);
            } else {
                putSanitisedName(field.getName(), bufferInFillMode);
                bufferInFillMode.put(__colon_space);
                putSanitisedValue(field.getValue(), bufferInFillMode);
            }

            BufferUtils.putCRLF(bufferInFillMode);
        }
    }

    static void putTo(HttpFields fields, ByteBuffer bufferInFillMode) {
        foreach (HttpField field ; fields) {
            if (field !is null)
                putTo(field, bufferInFillMode);
        }
        BufferUtils.putCRLF(bufferInFillMode);
    }
}
