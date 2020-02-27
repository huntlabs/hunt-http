module hunt.http.codec.http.decode.HttpParser;

import hunt.http.codec.http.model;
import hunt.http.codec.http.hpack.HpackEncoder;

import hunt.collection;
import hunt.util.DateTime;
import hunt.Exceptions;
import hunt.logging;
import hunt.text.Common;
import hunt.text.StringBuilder;
import hunt.util.ConverterUtils;

import core.time;

import std.algorithm;
import std.array;
import std.container.array;
import std.conv;
import std.string;


private bool contains(T)(T[] items, T item) {
    return items.canFind(item);
}


/* ------------------------------------------------------------ */

/**
 * A Parser for 1.0 and 1.1 as defined by RFC7230
 * <p>
 * This parser parses HTTP client and server messages from buffers
 * passed in the {@link #parseNext(ByteBuffer)} method.  The parsed
 * elements of the HTTP message are passed as event calls to the
 * {@link HttpHandler} instance the parser is constructed with.
 * If the passed handler is a {@link RequestHandler} then server side
 * parsing is performed and if it is a {@link ResponseHandler}, then
 * client side parsing is done.
 * </p>
 * <p>
 * The contract of the {@link HttpHandler} API is that if a call returns
 * true then the call to {@link #parseNext(ByteBuffer)} will return as
 * soon as possible also with a true response.  Typically this indicates
 * that the parsing has reached a stage where the caller should process
 * the events accumulated by the handler.    It is the preferred calling
 * style that handling such as calling a servlet to process a request,
 * should be done after a true return from {@link #parseNext(ByteBuffer)}
 * rather than from within the scope of a call like
 * {@link RequestHandler#messageComplete()}
 * </p>
 * <p>
 * For performance, the parse is heavily dependent on the
 * {@link Trie#getBest(ByteBuffer, int, int)} method to look ahead in a
 * single pass for both the structure ( : and CRLF ) and semantic (which
 * header and value) of a header.  Specifically the static {@link HttpHeader#CACHE}
 * is used to lookup common combinations of headers and values
 * (eg. "Connection: close"), or just header names (eg. "Connection:" ).
 * For headers who's value is not known statically (eg. Host, COOKIE) then a
 * per parser dynamic Trie of {@link HttpFields} from previous parsed messages
 * is used to help the parsing of subsequent messages.
 * </p>
 * <p>
 * The parser can work in varying compliance modes:
 * <dl>
 * <dt>RFC7230</dt><dd>(default) Compliance with RFC7230</dd>
 * <dt>RFC2616</dt><dd>Wrapped headers and HTTP/0.9 supported</dd>
 * <dt>LEGACY</dt><dd>(aka STRICT) Adherence to Servlet Specification requirement for
 * exact case of header names, bypassing the header caches, which are case insensitive,
 * otherwise equivalent to RFC2616</dd>
 * </dl>
 *
 * @see <a href="http://tools.ietf.org/html/rfc7230">RFC 7230</a>
 */
class HttpParser {

    enum INITIAL_URI_LENGTH = 256;
    private MonoTime startTime;

    /**
     * Cache of common {@link HttpField}s including: <UL>
     * <LI>Common static combinations such as:<UL>
     * <li>Connection: close
     * <li>Accept-Encoding: gzip
     * <li>Content-Length: 0
     * </ul>
     * <li>Combinations of Content-Type header for common mime types by common charsets
     * <li>Most common headers with null values so that a lookup will at least
     * determine the header name even if the name:value combination is not cached
     * </ul>
     */
    __gshared Trie!HttpField CACHE;

    // States
    enum FieldState {
        FIELD,
        IN_NAME,
        VALUE,
        IN_VALUE,
        WS_AFTER_NAME,
    }

    // States
    enum State {
        START,
        METHOD,
        RESPONSE_VERSION,
        SPACE1,
        STATUS,
        URI,
        SPACE2,
        REQUEST_VERSION,
        REASON,
        PROXY,
        HEADER,
        CONTENT,
        EOF_CONTENT,
        CHUNKED_CONTENT,
        CHUNK_SIZE,
        CHUNK_PARAMS,
        CHUNK,
        TRAILER,
        END,
        CLOSE,  // The associated stream/endpoint should be closed
        CLOSED  // The associated stream/endpoint is at EOF
    }

    private static State[] __idleStates = [State.START, State.END, State.CLOSE, State.CLOSED];
    private static State[] __completeStates = [State.END, State.CLOSE, State.CLOSED];

    private HttpHandler _handler;
    private RequestHandler _requestHandler;
    private ResponseHandler _responseHandler;
    private ComplianceHandler _complianceHandler;
    private int _maxHeaderBytes;
    private HttpCompliance _compliance;
    private HttpComplianceSection[] _compliances;
    private HttpField _field;
    private HttpHeader _header;
    private string _headerString;
    private string _valueString;
    private int _responseStatus;
    private int _headerBytes;
    private bool _host;
    private bool _headerComplete;

    /* ------------------------------------------------------------------------------- */
    private  State _state = State.START;
    private  FieldState _fieldState = FieldState.FIELD;
    private  bool _eof;
    private HttpMethod _method;
    private string _methodString;
    private HttpVersion _version;
    private StringBuilder _uri;
    private EndOfContent _endOfContent;
    private long _contentLength = -1;
    private long _contentPosition;
    private int _chunkLength;
    private int _chunkPosition;
    private bool _headResponse;
    private bool _cr;
    private ByteBuffer _contentChunk;
    private Trie!HttpField _fieldCache;

    private int _length;
    private StringBuilder _string; 

    shared static this() {
        CACHE = new ArrayTrie!HttpField(2048);
        CACHE.put(new HttpField(HttpHeader.CONNECTION, HttpHeaderValue.CLOSE));
        CACHE.put(new HttpField(HttpHeader.CONNECTION, HttpHeaderValue.KEEP_ALIVE));
        CACHE.put(new HttpField(HttpHeader.CONNECTION, HttpHeaderValue.UPGRADE));
        CACHE.put(new HttpField(HttpHeader.ACCEPT_ENCODING, "gzip"));
        CACHE.put(new HttpField(HttpHeader.ACCEPT_ENCODING, "gzip, deflate"));
        CACHE.put(new HttpField(HttpHeader.ACCEPT_ENCODING, "gzip, deflate, br"));
        CACHE.put(new HttpField(HttpHeader.ACCEPT_ENCODING, "gzip,deflate,sdch"));
        CACHE.put(new HttpField(HttpHeader.ACCEPT_LANGUAGE, "en-US,en;q=0.5"));
        CACHE.put(new HttpField(HttpHeader.ACCEPT_LANGUAGE, "en-GB,en-US;q=0.8,en;q=0.6"));

        CACHE.put(new HttpField(HttpHeader.ACCEPT_LANGUAGE, 
            "en-AU,en;q=0.9,it-IT;q=0.8,it;q=0.7,en-GB;q=0.6,en-US;q=0.5"));
            
        CACHE.put(new HttpField(HttpHeader.ACCEPT_CHARSET, "ISO-8859-1,utf-8;q=0.7,*;q=0.3"));
        CACHE.put(new HttpField(HttpHeader.ACCEPT, "*/*"));
        CACHE.put(new HttpField(HttpHeader.ACCEPT, "image/png,image/*;q=0.8,*/*;q=0.5"));
        CACHE.put(new HttpField(HttpHeader.ACCEPT, 
            "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"));

        CACHE.put(new HttpField(HttpHeader.ACCEPT, 
            "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8"));

        CACHE.put(new HttpField(HttpHeader.ACCEPT_RANGES, HttpHeaderValue.BYTES));
        CACHE.put(new HttpField(HttpHeader.PRAGMA, "no-cache"));

        CACHE.put(new HttpField(HttpHeader.CACHE_CONTROL, 
            "private, no-cache, no-cache=Set-Cookie, proxy-revalidate"));

        CACHE.put(new HttpField(HttpHeader.CACHE_CONTROL, "no-cache"));
        CACHE.put(new HttpField(HttpHeader.CACHE_CONTROL, "max-age=0"));
        CACHE.put(new HttpField(HttpHeader.CONTENT_LENGTH, "0"));
        CACHE.put(new HttpField(HttpHeader.CONTENT_ENCODING, "gzip"));
        CACHE.put(new HttpField(HttpHeader.CONTENT_ENCODING, "deflate"));
        CACHE.put(new HttpField(HttpHeader.TRANSFER_ENCODING, "chunked"));
        CACHE.put(new HttpField(HttpHeader.EXPIRES, "Fri, 01 Jan 1990 00:00:00 GMT"));

        // Add common Content types as fields
        foreach (string type ; ["text/plain", "text/html", "text/xml", "text/json", 
            "application/json", "application/x-www-form-urlencoded"]) {
            HttpField field = new PreEncodedHttpField(HttpHeader.CONTENT_TYPE, type);
            CACHE.put(field);

            foreach (string charset ; ["utf-8", "iso-8859-1"]) {
                CACHE.put(new PreEncodedHttpField(HttpHeader.CONTENT_TYPE, type ~ ";charset=" ~ charset));
                CACHE.put(new PreEncodedHttpField(HttpHeader.CONTENT_TYPE, type ~ "; charset=" ~ charset));
                CACHE.put(new PreEncodedHttpField(HttpHeader.CONTENT_TYPE, type ~ ";charset=" ~ charset.toUpper()));
                CACHE.put(new PreEncodedHttpField(HttpHeader.CONTENT_TYPE, type ~ "; charset=" ~ charset.toUpper()));
            }
        }

        // Add headers with null values so HttpParser can avoid looking up name again for unknown values
        foreach (HttpHeader h ; HttpHeader.values()) {
            // trace(h.toString());
            if (!CACHE.put(new HttpField(h, cast(string) null))) {
                // FIXME: Needing refactor or cleanup -@zxp at 9/25/2018, 8:11:29 PM
                // 
                // warning(h.toString());
                // throw new IllegalStateException("CACHE FULL");
            }
        }

        // Add some more common headers
        CACHE.put(new HttpField(HttpHeader.REFERER, cast(string) null));
        CACHE.put(new HttpField(HttpHeader.IF_MODIFIED_SINCE, cast(string) null));
        CACHE.put(new HttpField(HttpHeader.IF_NONE_MATCH, cast(string) null));
        CACHE.put(new HttpField(HttpHeader.AUTHORIZATION, cast(string) null));
        CACHE.put(new HttpField(HttpHeader.COOKIE, cast(string) null));
    }

    private static HttpCompliance getCompliance() {
        return HttpCompliance.RFC7230;
    }

    /* ------------------------------------------------------------------------------- */
    this(RequestHandler handler) {
        this(handler, -1, getCompliance());
    }

    /* ------------------------------------------------------------------------------- */
    this(ResponseHandler handler) {
        this(handler, -1, getCompliance());
    }

    /* ------------------------------------------------------------------------------- */
    this(RequestHandler handler, int maxHeaderBytes) {
        this(handler, maxHeaderBytes, getCompliance());
    }

    /* ------------------------------------------------------------------------------- */
    this(ResponseHandler handler, int maxHeaderBytes) {
        this(handler, maxHeaderBytes, getCompliance());
    }

    /* ------------------------------------------------------------------------------- */
    this(RequestHandler handler, HttpCompliance compliance) {
        this(handler, -1, compliance);
    }

    /* ------------------------------------------------------------------------------- */
    this(RequestHandler handler, int maxHeaderBytes, HttpCompliance compliance) {
        this(handler, null, maxHeaderBytes, compliance is null ? getCompliance() : compliance);
    }

    /* ------------------------------------------------------------------------------- */
    this(ResponseHandler handler, int maxHeaderBytes, HttpCompliance compliance) {
        this(null, handler, maxHeaderBytes, compliance is null ? getCompliance() : compliance);
    }

    /* ------------------------------------------------------------------------------- */
    private this(RequestHandler requestHandler, ResponseHandler responseHandler, 
        int maxHeaderBytes, HttpCompliance compliance) {
        version (HUNT_HTTP_DEBUG) {
            trace("create http parser");
        }
        _string = new StringBuilder();
        _uri = new StringBuilder(INITIAL_URI_LENGTH);
        _handler = requestHandler !is null ? cast(HttpHandler)requestHandler : cast(HttpHandler)responseHandler;
        _requestHandler = requestHandler;
        _responseHandler = responseHandler;
        _maxHeaderBytes = maxHeaderBytes;
        _compliance = compliance;
        _compliances = compliance.sections();
        _complianceHandler = cast(ComplianceHandler)_handler;
    }

    /* ------------------------------------------------------------------------------- */
    HttpHandler getHandler() {
        return _handler;
    }

    /* ------------------------------------------------------------------------------- */

    /**
     * Check RFC compliance violation
     *
     * @param violation The compliance section violation
     * @param reason    The reason for the violation
     * @return True if the current compliance level is set so as to Not allow this violation
     */
    protected bool complianceViolation(HttpComplianceSection violation, string reason) {
        if (_compliances.contains(violation))
            return true;

        if (_complianceHandler !is null)
            _complianceHandler.onComplianceViolation(_compliance, violation, reason);

        return false;
    }

    /* ------------------------------------------------------------------------------- */
    protected void handleViolation(HttpComplianceSection section, string reason) {
        if (_complianceHandler !is null)
            _complianceHandler.onComplianceViolation(_compliance, section, reason);
    }

    /* ------------------------------------------------------------------------------- */
    protected string caseInsensitiveHeader(string orig, string normative) {
        if (_compliances.contains(HttpComplianceSection.FIELD_NAME_CASE_INSENSITIVE))
            return normative;
        if (!orig.equals(normative))
            handleViolation(HttpComplianceSection.FIELD_NAME_CASE_INSENSITIVE, orig);
        return orig;
    }

    /* ------------------------------------------------------------------------------- */
    long getContentLength() {
        return _contentLength;
    }

    /* ------------------------------------------------------------ */
    long getContentRead() {
        return _contentPosition;
    }

    /* ------------------------------------------------------------ */

    /**
     * Set if a HEAD response is expected
     *
     * @param head true if head response is expected
     */
    void setHeadResponse(bool head) {
        _headResponse = head;
    }

    /* ------------------------------------------------------------------------------- */
    protected void setResponseStatus(int status) {
        _responseStatus = status;
    }

    /* ------------------------------------------------------------------------------- */
    State getState() {
        return _state;
    }

    /* ------------------------------------------------------------------------------- */
    bool inContentState() {
        return _state >= State.CONTENT && _state < State.END;
    }

    /* ------------------------------------------------------------------------------- */
    bool inHeaderState() {
        return _state < State.CONTENT;
    }

    /* ------------------------------------------------------------------------------- */
    bool isChunking() {
        return _endOfContent == EndOfContent.CHUNKED_CONTENT;
    }

    /* ------------------------------------------------------------ */
    bool isStart() {
        return isState(State.START);
    }

    /* ------------------------------------------------------------ */
    bool isClose() {
        return isState(State.CLOSE);
    }

    /* ------------------------------------------------------------ */
    bool isClosed() {
        return isState(State.CLOSED);
    }

    /* ------------------------------------------------------------ */
    bool isIdle() {
        return __idleStates.contains(_state);
    }

    /* ------------------------------------------------------------ */
    bool isComplete() {
        return __completeStates.contains(_state);
    }

    /* ------------------------------------------------------------------------------- */
    bool isState(State state) {
        return _state == state;
    }

    /* ------------------------------------------------------------------------------- */
    enum CharState {
        ILLEGAL, CR, LF, LEGAL
    }

    private static CharState[] __charState;

    static this() {
        // token          = 1*tchar
        // tchar          = "!" / "#" / "$" / "%" / "&" / "'" / "*"
        //                / "+" / "-" / "." / "^" / "_" / "`" / "|" / "~"
        //                / DIGIT / ALPHA
        //                ; any VCHAR, except delimiters
        // quoted-string  = DQUOTE *( qdtext / quoted-pair ) DQUOTE
        // qdtext         = HTAB / SP /%x21 / %x23-5B / %x5D-7E / obs-text
        // obs-text       = %x80-FF
        // comment        = "(" *( ctext / quoted-pair / comment ) ")"
        // ctext          = HTAB / SP / %x21-27 / %x2A-5B / %x5D-7E / obs-text
        // quoted-pair    = "\" ( HTAB / SP / VCHAR / obs-text )

        __charState = new CharState[256];
        __charState[0..$] = CharState.ILLEGAL;
        // Arrays.fill(__charState, CharState.ILLEGAL);
        __charState[HttpTokens.LINE_FEED] = CharState.LF;
        __charState[HttpTokens.CARRIAGE_RETURN] = CharState.CR;
        __charState[HttpTokens.TAB] = CharState.LEGAL;
        __charState[HttpTokens.SPACE] = CharState.LEGAL;

        __charState['!'] = CharState.LEGAL;
        __charState['#'] = CharState.LEGAL;
        __charState['$'] = CharState.LEGAL;
        __charState['%'] = CharState.LEGAL;
        __charState['&'] = CharState.LEGAL;
        __charState['\''] = CharState.LEGAL;
        __charState['*'] = CharState.LEGAL;
        __charState['+'] = CharState.LEGAL;
        __charState['-'] = CharState.LEGAL;
        __charState['.'] = CharState.LEGAL;
        __charState['^'] = CharState.LEGAL;
        __charState['_'] = CharState.LEGAL;
        __charState['`'] = CharState.LEGAL;
        __charState['|'] = CharState.LEGAL;
        __charState['~'] = CharState.LEGAL;

        __charState['"'] = CharState.LEGAL;

        __charState['\\'] = CharState.LEGAL;
        __charState['('] = CharState.LEGAL;
        __charState[')'] = CharState.LEGAL;
        __charState[0x21 .. 0x27 + 1] = CharState.LEGAL;
        __charState[0x2A .. 0x5B + 1] = CharState.LEGAL;
        __charState[0x5D .. 0x7E + 1] = CharState.LEGAL;
        __charState[0x80 .. 0xFF + 1] = CharState.LEGAL;
    }

    /* ------------------------------------------------------------------------------- */
    private byte next(ByteBuffer buffer) {
        byte ch = buffer.get();

        CharState s = __charState[0xff & ch];
        switch (s) {
            case CharState.ILLEGAL:
                throw new IllegalCharacterException(_state, ch, buffer);

            case CharState.LF:
                _cr = false;
                break;

            case CharState.CR:
                if (_cr)
                    throw new BadMessageException("Bad EOL");

                _cr = true;
                if (buffer.hasRemaining()) {
                    // Don't count the CRs and LFs of the chunked encoding.
                    if (_maxHeaderBytes > 0 && (_state == State.HEADER || _state == State.TRAILER))
                        _headerBytes++;
                    return next(buffer);
                }

                // Can return 0 here to indicate the need for more characters,
                // because a real 0 in the buffer would cause a BadMessage below
                return 0;

            case CharState.LEGAL:
                if (_cr)
                    throw new BadMessageException("Bad EOL");
                break;
            
            default:
                break;
        }

        return ch;
    }

    /* ------------------------------------------------------------------------------- */
    /* Quick lookahead for the start state looking for a request method or a HTTP version,
     * otherwise skip white space until something else to parse.
     */
    private bool quickStart(ByteBuffer buffer) {
        if (_requestHandler !is null) {
            _method = HttpMethod.lookAheadGet(buffer);
            if (_method != HttpMethod.Null) {
                _methodString = _method.asString();
                buffer.position(cast(int)(buffer.position() + _methodString.length + 1));

                setState(State.SPACE1);
                return false;
            }
        } else if (_responseHandler !is null) {
            _version = HttpVersion.lookAheadGet(buffer);
            if (_version != HttpVersion.Null) {
                buffer.position(cast(int) (buffer.position() + _version.asString().length + 1));
                setState(State.SPACE1);
                return false;
            }
        }

        // Quick start look
        while (_state == State.START && buffer.hasRemaining()) {
            int ch = next(buffer);

            if (ch > HttpTokens.SPACE) {
                _string.setLength(0);
                _string.append(cast(char) ch);
                setState(_requestHandler !is null ? State.METHOD : State.RESPONSE_VERSION);
                return false;
            } else if (ch == 0)
                break;
            else if (ch < 0)
                throw new BadMessageException();

            // count this white space as a header byte to avoid DOS
            if (_maxHeaderBytes > 0 && ++_headerBytes > _maxHeaderBytes) {
                warningf("padding is too large >%d", _maxHeaderBytes);
                throw new BadMessageException(HttpStatus.BAD_REQUEST_400);
            }
        }
        return false;
    }

    /* ------------------------------------------------------------------------------- */
    private void setString(string s) {
        _string.setLength(0);
        _string.append(s);
        _length = cast(int)s.length;
    }

    /* ------------------------------------------------------------------------------- */
    private string takeString() {
        _string.setLength(_length);
        string s = _string.toString();
        _string.setLength(0);
        _length = -1;
        return s;
    }

    /* ------------------------------------------------------------------------------- */
    private bool handleHeaderContentMessage() {
        version (HUNT_HTTP_DEBUG_MORE) trace("handling headers ...");
        bool handle_header = _handler.headerComplete();
        _headerComplete = true;
        version (HUNT_HTTP_DEBUG_MORE) trace("handling content ...");
        bool handle_content = _handler.contentComplete();
        version (HUNT_HTTP_DEBUG_MORE) trace("handling message ...");
        bool handle_message = _handler.messageComplete();
        return handle_header || handle_content || handle_message;
    }

    /* ------------------------------------------------------------------------------- */
    private bool handleContentMessage() {
        bool handle_content = _handler.contentComplete();
        bool handle_message = _handler.messageComplete();
        return handle_content || handle_message;
    }

    /* ------------------------------------------------------------------------------- */
    /* Parse a request or response line
     */
    private bool parseLine(ByteBuffer buffer) {
        bool handle = false;

        // Process headers
        while (_state < State.HEADER && buffer.hasRemaining() && !handle) {
            // process each character
            byte b = next(buffer);
            if (b == 0)
                break;

            if (_maxHeaderBytes > 0 && ++_headerBytes > _maxHeaderBytes) {
                if (_state == State.URI) {
                    warningf("URI is too large >%d", _maxHeaderBytes);
                    throw new BadMessageException(HttpStatus.URI_TOO_LONG_414);
                } else {
                    if (_requestHandler !is null)
                        warningf("request is too large >%d", _maxHeaderBytes);
                    else
                        warningf("response is too large >%d", _maxHeaderBytes);
                    throw new BadMessageException(HttpStatus.REQUEST_HEADER_FIELDS_TOO_LARGE_431);
                }
            }

            switch (_state) {
                case State.METHOD:
                    if (b == HttpTokens.SPACE) {
                        _length = _string.length;
                        _methodString = takeString();

                        if (_compliances.contains(HttpComplianceSection.METHOD_CASE_SENSITIVE)) {
                            HttpMethod method = HttpMethod.get(_methodString);
                            if (method != HttpMethod.Null)
                                _methodString = method.asString();
                        } else {
                            HttpMethod method = HttpMethod.getInsensitive(_methodString);

                            if (method != HttpMethod.Null) {
                                if (method.asString() != (_methodString))
                                    handleViolation(HttpComplianceSection.METHOD_CASE_SENSITIVE, _methodString);
                                _methodString = method.asString();
                            }
                        }

                        setState(State.SPACE1);
                    } else if (b < HttpTokens.SPACE) {
                        if (b == HttpTokens.LINE_FEED)
                            throw new BadMessageException("No URI");
                        else
                            throw new IllegalCharacterException(_state, b, buffer);
                    } else
                        _string.append(cast(char) b);
                    break;

                case State.RESPONSE_VERSION:
                    if (b == HttpTokens.SPACE) {
                        _length = _string.length;
                        string ver = takeString();
                        _version = HttpVersion.fromString(ver);
                        if (_version == HttpVersion.Null)
                            throw new BadMessageException(HttpStatus.BAD_REQUEST_400, "Unknown Version");
                        setState(State.SPACE1);
                    } else if (b < HttpTokens.SPACE)
                        throw new IllegalCharacterException(_state, b, buffer);
                    else
                        _string.append(cast(char) b);
                    break;

                case State.SPACE1:
                    if (b > HttpTokens.SPACE || b < 0) {
                        if (_responseHandler !is null) {
                            setState(State.STATUS);
                            setResponseStatus(b - '0');
                        } else {
                            _uri.reset();
                            setState(State.URI);
                            // quick scan for space or EoBuffer
                            if (buffer.hasArray()) {
                                byte[] array = buffer.array();
                                int p = buffer.arrayOffset() + buffer.position();
                                int l = buffer.arrayOffset() + buffer.limit();
                                int i = p;
                                while (i < l && array[i] > HttpTokens.SPACE)
                                    i++;

                                int len = i - p;
                                _headerBytes += len;

                                if (_maxHeaderBytes > 0 && ++_headerBytes > _maxHeaderBytes) {
                                    warningf("URI is too large >%d", _maxHeaderBytes);
                                    throw new BadMessageException(HttpStatus.URI_TOO_LONG_414);
                                }
                                _uri.append(array, p - 1, len + 1);
                                buffer.position(i - buffer.arrayOffset());
                            } else
                                _uri.append(b);
                        }
                    } else if (b < HttpTokens.SPACE) {
                        throw new BadMessageException(HttpStatus.BAD_REQUEST_400, 
                            _requestHandler !is null ? "No URI" : "No Status");
                    }
                    break;

                case State.STATUS:
                    if (b == HttpTokens.SPACE) {
                        setState(State.SPACE2);
                    } else if (b >= '0' && b <= '9') {
                        _responseStatus = _responseStatus * 10 + (b - '0');
                    } else if (b < HttpTokens.SPACE && b >= 0) {
                        setState(State.HEADER);
                        handle = _responseHandler.startResponse(_version, _responseStatus, null) || handle;
                    } else {
                        throw new BadMessageException();
                    }
                    break;

                case State.URI:
                    if (b == HttpTokens.SPACE) {
                        setState(State.SPACE2);
                    } else if (b < HttpTokens.SPACE && b >= 0) {
                        // HTTP/0.9
                        if (complianceViolation(HttpComplianceSection.NO_HTTP_0_9, "No request version"))
                            throw new BadMessageException("HTTP/0.9 not supported");
                        handle = _requestHandler.startRequest(_methodString, _uri.toString(), HttpVersion.HTTP_0_9);
                        setState(State.END);
                        BufferUtils.clear(buffer);
                        handle = handleHeaderContentMessage() || handle;
                    } else {
                        _uri.append(b);
                    }
                    break;

                case State.SPACE2:
                    if (b > HttpTokens.SPACE) {
                        _string.setLength(0);
                        _string.append(cast(char) b);
                        if (_responseHandler !is null) {
                            _length = 1;
                            setState(State.REASON);
                        } else {
                            setState(State.REQUEST_VERSION);

                            // try quick look ahead for HTTP Version
                            HttpVersion ver;
                            if (buffer.position() > 0 && buffer.hasArray()) {
                                ver = HttpVersion.lookAheadGet(buffer.array(), 
                                    buffer.arrayOffset() + buffer.position() - 1, 
                                    buffer.arrayOffset() + buffer.limit());
                            } else {
                                string key = buffer.getString(0, buffer.remaining());
                                ver = HttpVersion.fromString(key);
                            }

                            if (ver != HttpVersion.Null) {
                                int pos = cast(int)(buffer.position() + ver.asString().length - 1);
                                if (pos < buffer.limit()) {
                                    byte n = buffer.get(pos);
                                    if (n == HttpTokens.CARRIAGE_RETURN) {
                                        _cr = true;
                                        _version = ver;
                                        _string.setLength(0);
                                        buffer.position(pos + 1);
                                    } else if (n == HttpTokens.LINE_FEED) {
                                        _version = ver;
                                        _string.setLength(0);
                                        buffer.position(pos);
                                    }
                                }
                            }
                        }
                    } else if (b == HttpTokens.LINE_FEED) {
                        if (_responseHandler !is null) {
                            setState(State.HEADER);
                            handle = _responseHandler.startResponse(_version, _responseStatus, null) || handle;
                        } else {
                            // HTTP/0.9
                            if (complianceViolation(HttpComplianceSection.NO_HTTP_0_9, "No request version"))
                                throw new BadMessageException("HTTP/0.9 not supported");

                            handle = _requestHandler.startRequest(_methodString, _uri.toString(), HttpVersion.HTTP_0_9);
                            setState(State.END);
                            BufferUtils.clear(buffer);
                            handle = handleHeaderContentMessage() || handle;
                        }
                    } else if (b < 0)
                        throw new BadMessageException();
                    break;

                case State.REQUEST_VERSION:
                    if (b == HttpTokens.LINE_FEED) {
                        if (_version == HttpVersion.Null) {
                            _length = _string.length;
                            _version = HttpVersion.fromString(takeString());
                        }
                        if (_version == HttpVersion.Null)
                            throw new BadMessageException(HttpStatus.BAD_REQUEST_400, "Unknown Version");

                        // Should we try to cache header fields?
                        if (_fieldCache is null && 
                            _version.getVersion() >= HttpVersion.HTTP_1_1.getVersion() && 
                            _handler.getHeaderCacheSize() > 0) {
                            int header_cache = _handler.getHeaderCacheSize();
                            _fieldCache = new ArrayTernaryTrie!HttpField(header_cache);
                        }

                        setState(State.HEADER);

                        if(_requestHandler is null) {
                            warning("_requestHandler is null");
                        } else {
                            handle = _requestHandler.startRequest(_methodString, _uri.toString(), _version) || handle;
                        }
                        continue;
                    } else if (b >= HttpTokens.SPACE)
                        _string.append(cast(char) b);
                    else
                        throw new BadMessageException();

                    break;

                case State.REASON:
                    if (b == HttpTokens.LINE_FEED) {
                        string reason = takeString();
                        setState(State.HEADER);
                        handle = _responseHandler.startResponse(_version, _responseStatus, reason) || handle;
                        continue;
                    } else if (b >= HttpTokens.SPACE || ((b < 0) && (b >= -96))) {
                        _string.append(cast(char) (0xff & b));
                        if (b != ' ' && b != '\t')
                            _length = _string.length;
                    } else
                        throw new BadMessageException();
                    break;

                default:
                    throw new IllegalStateException(_state.to!string());
            }
        }

        return handle;
    }

    private void parsedHeader() {
        // handler last header if any.  Delayed to here just in case there was a continuation line (above)
        if (!_headerString.empty() || !_valueString.empty()) {
            // Handle known headers
            version(HUNT_HTTP_DEBUG_MORE) {
                tracef("parsing header: %s, original name: %s, value: %s ", 
                    _header.toString(), _headerString, _valueString);
            }

            if (_header != HttpHeader.Null) {
                bool canAddToConnectionTrie = false;
                if(_header == HttpHeader.CONTENT_LENGTH) {
                    if (_endOfContent == EndOfContent.CONTENT_LENGTH) {
                        throw new BadMessageException(HttpStatus.BAD_REQUEST_400, "Duplicate Content-Length");
                    } else if (_endOfContent != EndOfContent.CHUNKED_CONTENT) {
                        _contentLength = convertContentLength(_valueString);
                        if (_contentLength <= 0)
                            _endOfContent = EndOfContent.NO_CONTENT;
                        else
                            _endOfContent = EndOfContent.CONTENT_LENGTH;
                    }
                }
                else if(_header == HttpHeader.TRANSFER_ENCODING){
                    if (HttpHeaderValue.CHUNKED.isSame(_valueString)) {
                        _endOfContent = EndOfContent.CHUNKED_CONTENT;
                        _contentLength = -1;
                    } else {
                        string[] values = new QuotedCSV(_valueString).getValues();
                        if (values.length > 0 && HttpHeaderValue.CHUNKED.isSame(values[$ - 1])) {
                            _endOfContent = EndOfContent.CHUNKED_CONTENT;
                            _contentLength = -1;
                        } else {
                            foreach(string v; values) {
                                if(HttpHeaderValue.CHUNKED.isSame(v)) {
                                    throw new BadMessageException(HttpStatus.BAD_REQUEST_400, "Bad chunking");
                                }
                            }
                        } 
                    }
                }                    
                else if(_header == HttpHeader.HOST) {
                    _host = true;
                    if ((_field is null) && !_valueString.empty()) {
                        string headerStr = _compliances.contains(HttpComplianceSection.FIELD_NAME_CASE_INSENSITIVE) ? 
                                    _header.asString() : _headerString;
                        _field = new HostPortHttpField(_header, headerStr, _valueString);
                        canAddToConnectionTrie = _fieldCache !is null;
                    }
                }
                else if(_header == HttpHeader.CONNECTION) {
                    // Don't cache headers if not persistent
                    if (HttpHeaderValue.CLOSE.isSame(_valueString)) 
                        _fieldCache = null;
                    else {
                        string[] values = new QuotedCSV(_valueString).getValues();
                        foreach(string v; values) {
                            if(HttpHeaderValue.CLOSE.isSame(v)) {
                                _fieldCache = null;
                                break;
                            }
                        }
                    }
                }
                else if(_header == HttpHeader.AUTHORIZATION || _header == HttpHeader.ACCEPT ||
                _header == HttpHeader.ACCEPT_CHARSET || _header ==  HttpHeader.ACCEPT_ENCODING ||
                _header == HttpHeader.ACCEPT_LANGUAGE || _header == HttpHeader.COOKIE || 
                _header == HttpHeader.CACHE_CONTROL || _header == HttpHeader.USER_AGENT) {
                    canAddToConnectionTrie = _fieldCache !is null && _field is null;
                }

                if (canAddToConnectionTrie && !_fieldCache.isFull() 
                    && _header != HttpHeader.Null && !_valueString.empty()) {
                    if (_field is null)
                        _field = new HttpField(_header, caseInsensitiveHeader(_headerString, _header.asString()), _valueString);
                    _fieldCache.put(_field);
                }
            }
            _handler.parsedHeader(_field !is null ? _field : new HttpField(_header, _headerString, _valueString));
        }

        _headerString = _valueString = null;
        _header = HttpHeader.Null;
        _field = null;
    }

    private void parsedTrailer() {
        // handler last header if any.  Delayed to here just in case there was a continuation line (above)
        if (!_headerString.empty() || !_valueString.empty()) 
            _handler.parsedTrailer(_field !is null ? _field : new HttpField(_header, _headerString, _valueString));

        _headerString = _valueString = null;
        _header = HttpHeader.Null;
        _field = null;
    }

    private long convertContentLength(string valueString) {
        try {
            return to!long(valueString);
        } catch (Exception e) {
            warning("parse long exception: ", e);
            throw new BadMessageException(HttpStatus.BAD_REQUEST_400, "Invalid Content-Length Value");
        }
    }

    /* ------------------------------------------------------------------------------- */
    /*
     * Parse the message headers and return true if the handler has signaled for a return
     */
    protected bool parseFields(ByteBuffer buffer) {
        // Process headers
        while ((_state == State.HEADER || _state == State.TRAILER) && buffer.hasRemaining()) {
            // process each character
            byte b = next(buffer);
            if (b == 0)
                break;

            if (_maxHeaderBytes > 0 && ++_headerBytes > _maxHeaderBytes) {
                bool header = _state == State.HEADER;
                warningf("%s is too large %s>%s", header ? "Header" : "Trailer", _headerBytes, _maxHeaderBytes);
                throw new BadMessageException(header ?
                        HttpStatus.REQUEST_HEADER_FIELDS_TOO_LARGE_431 :
                        HttpStatus.PAYLOAD_TOO_LARGE_413);
            }

            switch (_fieldState) {
                case FieldState.FIELD:
                    switch (b) {
                        case HttpTokens.COLON:
                        case HttpTokens.SPACE:
                        case HttpTokens.TAB: {
                            if (complianceViolation(HttpComplianceSection.NO_FIELD_FOLDING, _headerString))
                                throw new BadMessageException(HttpStatus.BAD_REQUEST_400, "Header Folding");

                            // header value without name - continuation?
                            if (_valueString == null || _valueString.empty()) {
                                _string.setLength(0);
                                _length = 0;
                            } else {
                                setString(_valueString);
                                _string.append(' ');
                                _length++;
                                _valueString = null;
                            }
                            setState(FieldState.VALUE);
                            break;
                        }

                        case HttpTokens.LINE_FEED: {
                            // process previous header
                            if (_state == State.HEADER)
                                parsedHeader();
                            else
                                parsedTrailer();

                            _contentPosition = 0;

                            // End of headers or trailers?
                            if (_state == State.TRAILER) {
                                setState(State.END);
                                return _handler.messageComplete();
                            }

                            // Was there a required host header?
                            if (!_host && _version == HttpVersion.HTTP_1_1 && _requestHandler !is null) {
                                throw new BadMessageException(HttpStatus.BAD_REQUEST_400, "No Host");
                            }

                            // is it a response that cannot have a body?
                            if (_responseHandler !is null && // response
                                    (_responseStatus == 304 || // not-modified response
                                            _responseStatus == 204 || // no-content response
                                            _responseStatus < 200)) // 1xx response
                                _endOfContent = EndOfContent.NO_CONTENT; // ignore any other headers set

                                // else if we don't know framing
                            else if (_endOfContent == EndOfContent.UNKNOWN_CONTENT) {
                                if (_responseStatus == 0  // request
                                        || _responseStatus == 304 // not-modified response
                                        || _responseStatus == 204 // no-content response
                                        || _responseStatus < 200) // 1xx response
                                    _endOfContent = EndOfContent.NO_CONTENT;
                                else
                                    _endOfContent = EndOfContent.EOF_CONTENT;
                            }

                            // How is the message ended?
                            switch (_endOfContent) {
                                case EndOfContent.EOF_CONTENT: {
                                    setState(State.EOF_CONTENT);
                                    bool handle = _handler.headerComplete();
                                    _headerComplete = true;
                                    return handle;
                                }
                                case EndOfContent.CHUNKED_CONTENT: {
                                    setState(State.CHUNKED_CONTENT);
                                    bool handle = _handler.headerComplete();
                                    _headerComplete = true;
                                    return handle;
                                }
                                case EndOfContent.NO_CONTENT: {
                                    version (HUNT_HTTP_DEBUG) trace("parsing done for no content");
                                    setState(State.END);
                                    return handleHeaderContentMessage();
                                }
                                default: {
                                    setState(State.CONTENT);
                                    bool handle = _handler.headerComplete();
                                    _headerComplete = true;
                                    return handle;
                                }
                            }
                        }

                        default: {
                            // process previous header
                            if (_state == State.HEADER)
                                parsedHeader();
                            else
                                parsedTrailer();

                            // handle new header
                            if (buffer.hasRemaining()) {
                                // Try a look ahead for the known header name and value.
                                HttpField cached_field = null;
                                if(_fieldCache !is null)
                                    cached_field = _fieldCache.getBest(buffer, -1, buffer.remaining());
                                // TODO: Tasks pending completion -@zxp at 10/23/2018, 8:03:47 PM
                                // Can't handle Sec-WebSocket-Key
                                // if (cached_field is null)
                                //     cached_field = CACHE.getBest(buffer, -1, buffer.remaining());

                                if (cached_field !is null) {
                                    string n = cached_field.getName();
                                    string v = cached_field.getValue();

                                    if (!_compliances.contains(HttpComplianceSection.FIELD_NAME_CASE_INSENSITIVE)) {
                                        // Have to get the fields exactly from the buffer to match case
                                         // BufferUtils.toString(buffer, buffer.position() - 1, n.length, StandardCharsets.US_ASCII);
                                        string en = buffer.getString(buffer.position() - 1, cast(int)n.length);
                                        if (!n.equals(en)) {
                                            handleViolation(HttpComplianceSection.FIELD_NAME_CASE_INSENSITIVE, en);
                                            n = en;
                                            cached_field = new HttpField(cached_field.getHeader(), n, v);
                                        }
                                    }

                                    if (v != null && !_compliances.contains(HttpComplianceSection.CASE_INSENSITIVE_FIELD_VALUE_CACHE)) {
                                        // BufferUtils.toString(buffer, buffer.position() + n.length + 1, v.length, StandardCharsets.ISO_8859_1);
                                        string ev = buffer.getString(buffer.position() + n.length + 1, v.length);
                                        if (!v.equals(ev)) {
                                            handleViolation(HttpComplianceSection.CASE_INSENSITIVE_FIELD_VALUE_CACHE, ev ~ "!=" ~ v);
                                            v = ev;
                                            cached_field = new HttpField(cached_field.getHeader(), n, v);
                                        }
                                    }

                                    _header = cached_field.getHeader();
                                    _headerString = n;

                                    if (v == null) {
                                        // Header only
                                        setState(FieldState.VALUE);
                                        _string.setLength(0);
                                        _length = 0;
                                        buffer.position(cast(int)(buffer.position() + n.length + 1));
                                        break;
                                    } else {
                                        // Header and value
                                        int pos = cast(int) (buffer.position() + n.length + v.length + 1);
                                        byte peek = buffer.get(pos);

                                        if (peek == HttpTokens.CARRIAGE_RETURN || peek == HttpTokens.LINE_FEED) {
                                            _field = cached_field;
                                            _valueString = v;
                                            setState(FieldState.IN_VALUE);

                                            if (peek == HttpTokens.CARRIAGE_RETURN) {
                                                _cr = true;
                                                buffer.position(pos + 1);
                                            } else
                                                buffer.position(pos);
                                            break;
                                        } else {
                                            setState(FieldState.IN_VALUE);
                                            setString(v);
                                            buffer.position(pos);
                                            break;
                                        }
                                    }
                                }
                            }

                            // New header
                            setState(FieldState.IN_NAME);
                            _string.setLength(0);
                            _string.append(cast(char) b);
                            _length = 1;
                        }
                    }
                    break;

                case FieldState.IN_NAME:
                    switch (b) {
                        case HttpTokens.SPACE:
                        case HttpTokens.TAB:
                            //Ignore trailing whitespaces ?
                            if (!complianceViolation(HttpComplianceSection.NO_WS_AFTER_FIELD_NAME, null)) {
                                _headerString = takeString();
                                _header = HttpHeader.get(_headerString);
                                _length = -1;
                                setState(FieldState.WS_AFTER_NAME);
                                break;
                            }
                            throw new IllegalCharacterException(_state, b, buffer);

                        case HttpTokens.COLON:
                            _headerString = takeString();
                            _header = HttpHeader.get(_headerString);
                            _length = -1;
                            setState(FieldState.VALUE);
                            break;

                        case HttpTokens.LINE_FEED:
                            _headerString = takeString();
                            _header = HttpHeader.get(_headerString);
                            _string.setLength(0);
                            _valueString = "";
                            _length = -1;

                            if (!complianceViolation(HttpComplianceSection.FIELD_COLON, _headerString)) {
                                setState(FieldState.FIELD);
                                break;
                            }
                            throw new IllegalCharacterException(_state, b, buffer);

                        default:
                            if (b < 0)
                                throw new IllegalCharacterException(_state, b, buffer);

                            _string.append(cast(char) b);
                            _length = _string.length;
                            break;
                    }
                    break;

                case FieldState.WS_AFTER_NAME:

                    switch (b) {
                        case HttpTokens.SPACE:
                        case HttpTokens.TAB:
                            break;

                        case HttpTokens.COLON:
                            setState(FieldState.VALUE);
                            break;

                        case HttpTokens.LINE_FEED:
                            if (!complianceViolation(HttpComplianceSection.FIELD_COLON, _headerString)) {
                                setState(FieldState.FIELD);
                                break;
                            }
                            throw new IllegalCharacterException(_state, b, buffer);

                        default:
                            throw new IllegalCharacterException(_state, b, buffer);
                    }
                    break;

                case FieldState.VALUE:
                    switch (b) {
                        case HttpTokens.LINE_FEED:
                            _string.setLength(0);
                            _valueString = "";
                            _length = -1;

                            setState(FieldState.FIELD);
                            break;

                        case HttpTokens.SPACE:
                        case HttpTokens.TAB:
                            break;

                        default:
                            _string.append(cast(char) (0xff & b));
                            _length = _string.length;
                            setState(FieldState.IN_VALUE);
                            break;
                    }
                    break;

                case FieldState.IN_VALUE:
                    switch (b) {
                        case HttpTokens.LINE_FEED:
                            if (_length > 0) {
                                _valueString = takeString();
                                _length = -1;
                            }
                            setState(FieldState.FIELD);
                            break;

                        case HttpTokens.SPACE:
                        case HttpTokens.TAB:
                            _string.append(cast(char) (0xff & b));
                            break;

                        default:
                            _string.append(cast(char) (0xff & b));
                            _length = _string.length;
                            break;
                    }
                    break;

                default:
                    throw new IllegalStateException(_state.to!string());

            }
        }

        return false;
    }

    /* ------------------------------------------------------------------------------- */

    /**
     * Parse until next Event.
     *
     * @param buffer the buffer to parse
     * @return True if an {@link RequestHandler} method was called and it returned true;
     */
    bool parseNext(ByteBuffer buffer) {
        version(HUNT_HTTP_DEBUG_MORE) {
            tracef("parseNext s=%s %s", _state, BufferUtils.toDetailString(buffer));
            // tracef("buffer: %s", BufferUtils.toHexString(buffer));

            // startTime = MonoTime.currTime;
            // _requestHandler.startRequest("GET", "/plaintext", HttpVersion.HTTP_1_1);
            // setState(State.END);
            // _handler.messageComplete();
            // BufferUtils.clear(buffer);
            // return false;
        }
        try {
            // Start a request/response
            if (_state == State.START) {
                version(HUNT_METRIC) {
                    startTime = MonoTime.currTime;
                    info("start a new parsing process...");
                }                
                _version = HttpVersion.Null;
                _method = HttpMethod.Null;
                _methodString = null;
                _endOfContent = EndOfContent.UNKNOWN_CONTENT;
                _header = HttpHeader.Null;
                if (quickStart(buffer))
                    return true;
            }

            // Request/response line
            if (_state >= State.START && _state < State.HEADER) {
                if (parseLine(buffer)) {
                    tracef("after parseLine =>%s", buffer.toString());
                    // return true;
                }
            }

            // parse headers
            if (_state == State.HEADER) {
                if (parseFields(buffer)) {
                    version(HUNT_HTTP_DEBUG_MORE) tracef("after parseFields =>%s", buffer.toString());
                    return true;
                }
            }

            // parse content
            if (_state >= State.CONTENT && _state < State.TRAILER) {
                // Handle HEAD response
                if (_responseStatus > 0 && _headResponse) {
                    setState(State.END);
                    return handleContentMessage();
                } else {
                    if (parseContent(buffer))
                        return true;
                }
            }

            // parse headers
            if (_state == State.TRAILER) {
                if (parseFields(buffer))
                    return true;
            }

            // handle end states
            if (_state == State.END) {
                // eat white space
                while (buffer.remaining() > 0 && buffer.get(buffer.position()) <= HttpTokens.SPACE)
                    buffer.get();
            } else if (isClose() || isClosed()) {
                BufferUtils.clear(buffer);
            }

            // Handle EOF
            if (_eof && !buffer.hasRemaining()) {
                switch (_state) {
                    case State.CLOSED:
                        break;

                    case State.START:
                        setState(State.CLOSED);
                        _handler.earlyEOF();
                        break;

                    case State.END:
                    case State.CLOSE:
                        setState(State.CLOSED);
                        break;

                    case State.EOF_CONTENT:
                    case State.TRAILER:
                        if (_fieldState == FieldState.FIELD) {
                            // Be forgiving of missing last CRLF
                            setState(State.CLOSED);
                            return handleContentMessage();
                        }
                        setState(State.CLOSED);
                        _handler.earlyEOF();
                        break;

                    case State.CONTENT:
                    case State.CHUNKED_CONTENT:
                    case State.CHUNK_SIZE:
                    case State.CHUNK_PARAMS:
                    case State.CHUNK:
                        setState(State.CLOSED);
                        _handler.earlyEOF();
                        break;

                    default:
                        version(HUNT_HTTP_DEBUG)
                            tracef("%s EOF in %s", this, _state);
                        setState(State.CLOSED);
                        _handler.badMessage(new BadMessageException(HttpStatus.BAD_REQUEST_400));
                        break;
                }
            }
        } catch (BadMessageException x) {
            BufferUtils.clear(buffer);
            badMessage(x);
        } catch (Exception x) {
            BufferUtils.clear(buffer);
            badMessage(new BadMessageException(HttpStatus.BAD_REQUEST_400, 
                _requestHandler !is null ? "Bad Request" : "Bad Response", x));
        }
        return false;
    }

    protected void badMessage(BadMessageException x) {
        // version(HUNT_HTTP_DEBUG)
            warning("Parse exception: " ~ this.toString() ~ " for " ~ _handler.toString() ~ 
                ", Exception: ", x.msg);
        version(HUNT_HTTP_DEBUG) {
            Throwable t = x;
            while((t = t.next) !is null) {
                error(t.msg);
            }
        }
        setState(State.CLOSE);
        if (_headerComplete)
            _handler.earlyEOF();
        else
            _handler.badMessage(x);
    }

    protected bool parseContent(ByteBuffer buffer) {
        int remaining = buffer.remaining();
        if (remaining == 0 && _state == State.CONTENT) {
            long content = _contentLength - _contentPosition;
            if (content == 0) {
                setState(State.END);
                return handleContentMessage();
            }
        }

        // Handle _content
        byte ch;
        while (_state < State.TRAILER && remaining > 0) {
            switch (_state) {
                case State.EOF_CONTENT:
                    _contentChunk = buffer.slice(); // buffer.asReadOnlyBuffer();
                    _contentPosition += remaining;
                    buffer.position(buffer.position() + remaining);
                    if (_handler.content(_contentChunk))
                        return true;
                    break;

                case State.CONTENT: {
                    long content = _contentLength - _contentPosition;
                    if (content == 0) {
                        setState(State.END);
                        return handleContentMessage();
                    } else {
                        _contentChunk = buffer.slice(); // buffer.asReadOnlyBuffer();

                        // limit content by expected size
                        if (remaining > content) {
                            // We can cast remaining to an int as we know that it is smaller than
                            // or equal to length which is already an int.
                            _contentChunk.limit(_contentChunk.position() + cast(int) content);
                        }

                        _contentPosition += _contentChunk.remaining();
                        buffer.position(buffer.position() + _contentChunk.remaining());
                        version(HUNT_HTTP_DEBUG) trace("setting content...");
                        if (_handler.content(_contentChunk))
                            return true;

                        if (_contentPosition == _contentLength) {
                            setState(State.END);
                            return handleContentMessage();
                        }
                    }
                    break;
                }

                case State.CHUNKED_CONTENT: {
                    ch = next(buffer);
                    if (ch > HttpTokens.SPACE) {
                        _chunkLength = ConverterUtils.convertHexDigit(ch);
                        _chunkPosition = 0;
                        setState(State.CHUNK_SIZE);
                    }

                    break;
                }

                case State.CHUNK_SIZE: {
                    ch = next(buffer);
                    if (ch == 0)
                        break;
                    if (ch == HttpTokens.LINE_FEED) {
                        if (_chunkLength == 0) {
                            setState(State.TRAILER);
                            if (_handler.contentComplete())
                                return true;
                        } else
                            setState(State.CHUNK);
                    } else if (ch <= HttpTokens.SPACE || ch == HttpTokens.SEMI_COLON)
                        setState(State.CHUNK_PARAMS);
                    else
                        _chunkLength = _chunkLength * 16 + ConverterUtils.convertHexDigit(ch);
                    break;
                }

                case State.CHUNK_PARAMS: {
                    ch = next(buffer);
                    if (ch == HttpTokens.LINE_FEED) {
                        if (_chunkLength == 0) {
                            setState(State.TRAILER);
                            if (_handler.contentComplete())
                                return true;
                        } else
                            setState(State.CHUNK);
                    }
                    break;
                }

                case State.CHUNK: {
                    int chunk = _chunkLength - _chunkPosition;
                    if (chunk == 0) {
                        setState(State.CHUNKED_CONTENT);
                    } else {
                        _contentChunk = buffer.slice(); // buffer.asReadOnlyBuffer();

                        if (remaining > chunk)
                            _contentChunk.limit(_contentChunk.position() + chunk);
                        chunk = _contentChunk.remaining();

                        _contentPosition += chunk;
                        _chunkPosition += chunk;
                        buffer.position(buffer.position() + chunk);
                        if (_handler.content(_contentChunk))
                            return true;
                    }
                    break;
                }

                case State.CLOSED: {
                    // BufferUtils.clear(buffer);
                    buffer.clear();
                    return false;
                }

                default:
                    break;

            }

            remaining = buffer.remaining();
        }
        return false;
    }

    /* ------------------------------------------------------------------------------- */
    bool isAtEOF()
    {
        return _eof;
    }

    /* ------------------------------------------------------------------------------- */

    /**
     * Signal that the associated data source is at EOF
     */
    void atEOF() {
        version(HUNT_HTTP_DEBUG)
            tracef("atEOF %s", this);
        _eof = true;
    }

    /* ------------------------------------------------------------------------------- */

    /**
     * Request that the associated data source be closed
     */
    void close() {
        version(HUNT_HTTP_DEBUG)
            tracef("close %s", this);
        setState(State.CLOSE);
    }

    /* ------------------------------------------------------------------------------- */
    void reset() {
        version(HUNT_HTTP_DEBUG_MORE)
            tracef("reset %s", this);

        // reset state
        if (_state == State.CLOSE || _state == State.CLOSED)
            return;

        setState(State.START);
        _endOfContent = EndOfContent.UNKNOWN_CONTENT;
        _contentLength = -1;
        _contentPosition = 0;
        _responseStatus = 0;
        _contentChunk = null;
        _headerBytes = 0;
        _host = false;
        _headerComplete = false;
    }

    /* ------------------------------------------------------------------------------- */
    protected void setState(State state) {
        // version(HUNT_HTTP_DEBUG)
        //     tracef("%s --> %s", _state, state);
        _state = state;
    
        version(HUNT_METRIC) {
            if(state == State.END) {
                Duration timeElapsed = MonoTime.currTime - startTime;
                warningf("parsing ended in: %d microseconds", timeElapsed.total!(TimeUnit.Microsecond)());
            }
        }
    }

    /* ------------------------------------------------------------------------------- */
    protected void setState(FieldState state) {
        // version(HUNT_HTTP_DEBUG)
        //     tracef("%s:%s --> %s", _state, _field, state);
        _fieldState = state;
    }

    /* ------------------------------------------------------------------------------- */
    Trie!HttpField getFieldCache() {
        return _fieldCache;
    }

    HttpField getCachedField(string name) {
        return _fieldCache.get(name);
    }
    

    /* ------------------------------------------------------------------------------- */
    override
    string toString() {
        return format("%s{s=%s,%d of %d}",
                typeof(this).stringof,
                _state,
                _contentPosition,
                _contentLength);
    }

    /* ------------------------------------------------------------ */
    /* ------------------------------------------------------------ */
    /* ------------------------------------------------------------ */
    /* Event Handler interface
     * These methods return true if the caller should process the events
     * so far received (eg return from parseNext and call HttpChannel.handle).
     * If multiple callbacks are called in sequence (eg
     * headerComplete then messageComplete) from the same point in the parsing
     * then it is sufficient for the caller to process the events only once.
     */
    interface HttpHandler {

        bool content(ByteBuffer item);

        bool headerComplete();

        bool contentComplete();

        bool messageComplete();

        /**
         * This is the method called by parser when a HTTP Header name and value is found
         *
         * @param field The field parsed
         */
        void parsedHeader(HttpField field);

        /**
         * This is the method called by parser when a HTTP Trailer name and value is found
         *
         * @param field The field parsed
         */
        void parsedTrailer(HttpField field);

        /* ------------------------------------------------------------ */

        /**
         * Called to signal that an EOF was received unexpectedly
         * during the parsing of a HTTP message
         */
        void earlyEOF();

        /* ------------------------------------------------------------ */

        /**
         * Called to signal that a bad HTTP message has been received.
         *
         * @param failure the failure with the bad message information
         */
        void badMessage(BadMessageException failure);
        // {
        //     // badMessage(failure.getCode(), failure.getReason());
        //     throw new BadMessageException(failure.getCode(), failure.getReason());
        // }

        /**
         * @deprecated use {@link #badMessage(BadMessageException)} instead
         */
        // deprecated("")
        void badMessage(int status, string reason);

        /* ------------------------------------------------------------ */

        /**
         * @return the size in bytes of the per parser header cache
         */
        int getHeaderCacheSize();

        string toString();
    }

    /* ------------------------------------------------------------------------------- */
    /* ------------------------------------------------------------------------------- */
    /* ------------------------------------------------------------------------------- */
    interface RequestHandler : HttpHandler {
        /**
         * This is the method called by parser when the HTTP request line is parsed
         *
         * @param method  The method
         * @param uri     The raw bytes of the URI.  These are copied into a ByteBuffer that will not be changed until this parser is reset and reused.
         * @param version the http version in use
         * @return true if handling parsing should return.
         */
        bool startRequest(string method, string uri, HttpVersion ver);

    }

    /* ------------------------------------------------------------------------------- */
    /* ------------------------------------------------------------------------------- */
    /* ------------------------------------------------------------------------------- */
    interface ResponseHandler : HttpHandler {
        /**
         * This is the method called by parser when the HTTP request line is parsed
         *
         * @param version the http version in use
         * @param status  the response status
         * @param reason  the response reason phrase
         * @return true if handling parsing should return
         */
        bool startResponse(HttpVersion ver, int status, string reason);
    }

    /* ------------------------------------------------------------------------------- */
    /* ------------------------------------------------------------------------------- */
    /* ------------------------------------------------------------------------------- */
    interface ComplianceHandler : HttpHandler {
        // deprecated("")
        // default void onComplianceViolation(HttpCompliance compliance, HttpCompliance required, string reason) {
        // }

        void onComplianceViolation(HttpCompliance compliance, HttpComplianceSection v, string details);
        // {
        //     // onComplianceViolation(compliance, HttpCompliance.requiredCompliance(violation), details);
        //     warning(details);
        // }
    }

    /* ------------------------------------------------------------------------------- */
    
    private static class IllegalCharacterException : BadMessageException {
        private this(State state, byte ch, ByteBuffer buffer) {
            super(400, format("Illegal character 0x%X", ch));
            // Bug #460642 - don't reveal buffers to end user
            warningf("Illegal character 0x%X in state=%s for buffer %s", ch, state, BufferUtils.toDetailString(buffer));
        }
    }
}


alias HttpRequestHandler = HttpParser.RequestHandler;
alias HttpResponseHandler = HttpParser.ResponseHandler;
