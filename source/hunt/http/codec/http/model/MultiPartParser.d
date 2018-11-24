module hunt.http.codec.http.model.MultiPartParser;

import hunt.http.codec.http.model.BadMessageException;

import hunt.container.ByteBuffer;
import hunt.container.BufferUtils;
import hunt.string;
import hunt.lang.exception;
import hunt.logging;
import hunt.util.SearchPattern;

import std.algorithm;
import std.conv;
import std.format;


/* ------------------------------------------------------------ */

/**
 * A parser for MultiPart content type.
 *
 * @see <a href="https://tools.ietf.org/html/rfc2046#section-5.1">https://tools.ietf.org/html/rfc2046#section-5.1</a>
 * @see <a href="https://tools.ietf.org/html/rfc2045">https://tools.ietf.org/html/rfc2045</a>
 */
class MultiPartParser {
    enum byte COLON = ':';
    enum byte TAB = 0x09;
    enum byte LINE_FEED = 0x0A;
    enum byte CARRIAGE_RETURN = 0x0D;
    enum byte SPACE = 0x20;
    enum byte[] CRLF = [CARRIAGE_RETURN, LINE_FEED];
    enum byte SEMI_COLON = ';';

    // States
    enum FieldState {
        FIELD,
        IN_NAME,
        AFTER_NAME,
        VALUE,
        IN_VALUE
    }

    // States
    enum State {
        PREAMBLE,
        DELIMITER,
        DELIMITER_PADDING,
        DELIMITER_CLOSE,
        BODY_PART,
        FIRST_OCTETS,
        OCTETS,
        EPILOGUE,
        END
    }

    private enum State[] __delimiterStates = [State.DELIMITER, State.DELIMITER_CLOSE, State.DELIMITER_PADDING];

    private MultiPartParserHandler _handler;
    private SearchPattern _delimiterSearch;

    private string _fieldName;
    private string _fieldValue;

    private State _state = State.PREAMBLE;
    private FieldState _fieldState = FieldState.FIELD;
    private int _partialBoundary = 2; // No CRLF if no preamble
    private bool _cr;
    private ByteBuffer _patternBuffer;

    private StringBuilder _string;
    private size_t _length;

    private int _totalHeaderLineLength = -1;
    private int _maxHeaderLineLength = 998;

    /* ------------------------------------------------------------------------------- */
    this(MultiPartParserHandler handler, string boundary) {
        _handler = handler;
        _string = new StringBuilder();

        string delimiter = "\r\n--" ~ boundary;
        //delimiter.getBytes(StandardCharsets.US_ASCII)
        _patternBuffer = ByteBuffer.wrap(cast(byte[])delimiter.dup); 
        _delimiterSearch = SearchPattern.compile(_patternBuffer.array());
    }

    void reset() {
        _state = State.PREAMBLE;
        _fieldState = FieldState.FIELD;
        _partialBoundary = 2; // No CRLF if no preamble
    }

    /* ------------------------------------------------------------------------------- */
    MultiPartParserHandler getHandler() {
        return _handler;
    }

    /* ------------------------------------------------------------------------------- */
    State getState() {
        return _state;
    }

    /* ------------------------------------------------------------------------------- */
    bool isState(State state) {
        return _state == state;
    }

    /* ------------------------------------------------------------------------------- */
    enum CharState {
        ILLEGAL, CR, LF, LEGAL
    }

    private __gshared CharState[] __charState;

    shared static this() {
        // token = 1*tchar
        // tchar = "!" / "#" / "$" / "%" / "&" / "'" / "*"
        // / "+" / "-" / "." / "^" / "_" / "`" / "|" / "~"
        // / DIGIT / ALPHA
        // ; any VCHAR, except delimiters
        // quoted-string = DQUOTE *( qdtext / quoted-pair ) DQUOTE
        // qdtext = HTAB / SP /%x21 / %x23-5B / %x5D-7E / obs-text
        // obs-text = %x80-FF
        // comment = "(" *( ctext / quoted-pair / comment ) ")"
        // ctext = HTAB / SP / %x21-27 / %x2A-5B / %x5D-7E / obs-text
        // quoted-pair = "\" ( HTAB / SP / VCHAR / obs-text )

        __charState = new CharState[256];
        __charState[0..$] = CharState.ILLEGAL;

        __charState[LINE_FEED] = CharState.LF;
        __charState[CARRIAGE_RETURN] = CharState.CR;
        __charState[TAB] = CharState.LEGAL;
        __charState[SPACE] = CharState.LEGAL;

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

        // Arrays.fill(__charState, 0x21, 0x27 + 1, CharState.LEGAL);
        // Arrays.fill(__charState, 0x2A, 0x5B + 1, CharState.LEGAL);
        // Arrays.fill(__charState, 0x5D, 0x7E + 1, CharState.LEGAL);
        // Arrays.fill(__charState, 0x80, 0xFF + 1, CharState.LEGAL);

    }

    /* ------------------------------------------------------------------------------- */
    private bool hasNextByte(ByteBuffer buffer) {
        return BufferUtils.hasContent(buffer);
    }

    /* ------------------------------------------------------------------------------- */
    private byte getNextByte(ByteBuffer buffer) {

        byte ch = buffer.get();

        CharState s = __charState[0xff & ch];
        switch (s) {
            case CharState.LF:
                _cr = false;
                return ch;

            case CharState.CR:
                if (_cr)
                    throw new BadMessageException("Bad EOL");

                _cr = true;
                if (buffer.hasRemaining())
                    return getNextByte(buffer);

                // Can return 0 here to indicate the need for more characters,
                // because a real 0 in the buffer would cause a BadMessage below
                return 0;

            case CharState.LEGAL:
                if (_cr)
                    throw new BadMessageException("Bad EOL");

                return ch;

            case CharState.ILLEGAL:
            default:
                throw new IllegalCharacterException(_state, ch, buffer);
        }
    }

    /* ------------------------------------------------------------------------------- */
    private void setString(string s) {
        _string.reset();
        _string.append(s);
        _length = s.length;
    }

    /* ------------------------------------------------------------------------------- */
    /*
     * Mime Field strings are treated as UTF-8 as per https://tools.ietf.org/html/rfc7578#section-5.1
     */
    private string takeString() {
        string s = _string.toString();
        // trim trailing whitespace.
        if (s.length > _length)
            s = s.substring(0, _length);
        _string.reset();
        _length = -1;
        return s;
    }

    /* ------------------------------------------------------------------------------- */

    /**
     * Parse until next Event.
     *
     * @param buffer the buffer to parse
     * @param last   whether this buffer contains last bit of content
     * @return True if an {@link hunt.http.codec.http.decode.HttpParser.RequestHandler} method was called and it returned true;
     */
    bool parse(ByteBuffer buffer, bool last) {
        bool handle = false;
        while (handle == false && BufferUtils.hasContent(buffer)) {
            switch (_state) {
                case State.PREAMBLE:
                    parsePreamble(buffer);
                    continue;

                case State.DELIMITER:
                case State.DELIMITER_PADDING:
                case State.DELIMITER_CLOSE:
                    parseDelimiter(buffer);
                    continue;

                case State.BODY_PART:
                    handle = parseMimePartHeaders(buffer);
                    break;

                case State.FIRST_OCTETS:
                case State.OCTETS:
                    handle = parseOctetContent(buffer);
                    break;

                case State.EPILOGUE:
                    BufferUtils.clear(buffer);
                    break;

                case State.END:
                    handle = true;
                    break;

                default:
                    throw new IllegalStateException("");

            }
        }

        if (last && BufferUtils.isEmpty(buffer)) {
            if (_state == State.EPILOGUE) {
                _state = State.END;

                version(HUNT_DEBUG)
                    tracef("messageComplete %s", this);

                return _handler.messageComplete();
            } else {
                version(HUNT_DEBUG)
                    tracef("earlyEOF %s", this);

                _handler.earlyEOF();
                return true;
            }
        }

        return handle;
    }

    /* ------------------------------------------------------------------------------- */
    private void parsePreamble(ByteBuffer buffer) {
        if (_partialBoundary > 0) {
            int partial = _delimiterSearch.startsWith(buffer.array(), buffer.arrayOffset() + buffer.position(), 
                buffer.remaining(), _partialBoundary);
            if (partial > 0) {
                if (partial == _delimiterSearch.getLength()) {
                    buffer.position(buffer.position() + partial - _partialBoundary);
                    _partialBoundary = 0;
                    setState(State.DELIMITER);
                    return;
                }

                _partialBoundary = partial;
                BufferUtils.clear(buffer);
                return;
            }

            _partialBoundary = 0;
        }

        int delimiter = _delimiterSearch.match(buffer.array(), buffer.arrayOffset() + buffer.position(), buffer.remaining());
        if (delimiter >= 0) {
            buffer.position(delimiter - buffer.arrayOffset() + _delimiterSearch.getLength());
            setState(State.DELIMITER);
            return;
        }

        _partialBoundary = _delimiterSearch.endsWith(buffer.array(), 
            buffer.arrayOffset() + buffer.position(), buffer.remaining());
        BufferUtils.clear(buffer);

        return;
    }

    /* ------------------------------------------------------------------------------- */
    private void parseDelimiter(ByteBuffer buffer) {
        while (__delimiterStates.canFind(_state) && hasNextByte(buffer)) {
            byte b = getNextByte(buffer);
            if (b == 0)
                return;

            if (b == '\n') {
                setState(State.BODY_PART);

                version(HUNT_DEBUG)
                    tracef("startPart %s", this);

                _handler.startPart();
                return;
            }

            switch (_state) {
                case State.DELIMITER:
                    if (b == '-')
                        setState(State.DELIMITER_CLOSE);
                    else
                        setState(State.DELIMITER_PADDING);
                    continue;

                case State.DELIMITER_CLOSE:
                    if (b == '-') {
                        setState(State.EPILOGUE);
                        return;
                    }
                    setState(State.DELIMITER_PADDING);
                    continue;

                case State.DELIMITER_PADDING:
                default:
                    continue;
            }
        }
    }

    /* ------------------------------------------------------------------------------- */
    /*
     * Parse the message headers and return true if the handler has signaled for a return
     */
    protected bool parseMimePartHeaders(ByteBuffer buffer) {
        // Process headers
        while (_state == State.BODY_PART && hasNextByte(buffer)) {
            // process each character
            byte b = getNextByte(buffer);
            if (b == 0)
                break;

            if (b != LINE_FEED)
                _totalHeaderLineLength++;

            if (_totalHeaderLineLength > _maxHeaderLineLength)
                throw new IllegalStateException("Header Line Exceeded Max Length");

            switch (_fieldState) {
                case FieldState.FIELD:
                    switch (b) {
                        case SPACE:
                        case TAB: {
                            // Folded field value!

                            if (_fieldName == null)
                                throw new IllegalStateException("First field folded");

                            if (_fieldValue == null) {
                                _string.reset();
                                _length = 0;
                            } else {
                                setString(_fieldValue);
                                _string.append(' ');
                                _length++;
                                _fieldValue = null;
                            }
                            setState(FieldState.VALUE);
                            break;
                        }

                        case LINE_FEED: {
                            handleField();
                            setState(State.FIRST_OCTETS);
                            _partialBoundary = 2; // CRLF is option for empty parts

                            version(HUNT_DEBUG)
                                tracef("headerComplete %s", this);

                            if (_handler.headerComplete())
                                return true;
                            break;
                        }

                        default: {
                            // process previous header
                            handleField();

                            // New header
                            setState(FieldState.IN_NAME);
                            _string.reset();
                            _string.append(b);
                            _length = 1;
                        }
                    }
                    break;

                case FieldState.IN_NAME:
                    switch (b) {
                        case COLON:
                            _fieldName = takeString();
                            _length = -1;
                            setState(FieldState.VALUE);
                            break;

                        case SPACE:
                            // Ignore trailing whitespaces
                            setState(FieldState.AFTER_NAME);
                            break;

                        case LINE_FEED: {
                            version(HUNT_DEBUG)
                                tracef("Line Feed in Name %s", this);

                            handleField();
                            setState(FieldState.FIELD);
                            break;
                        }

                        default:
                            _string.append(b);
                            _length = _string.length;
                            break;
                    }
                    break;

                case FieldState.AFTER_NAME:
                    switch (b) {
                        case COLON:
                            _fieldName = takeString();
                            _length = -1;
                            setState(FieldState.VALUE);
                            break;

                        case LINE_FEED:
                            _fieldName = takeString();
                            _string.reset();
                            _fieldValue = "";
                            _length = -1;
                            break;

                        case SPACE:
                            break;

                        default:
                            throw new IllegalCharacterException(_state, b, buffer);
                    }
                    break;

                case FieldState.VALUE:
                    switch (b) {
                        case LINE_FEED:
                            _string.reset();
                            _fieldValue = "";
                            _length = -1;

                            setState(FieldState.FIELD);
                            break;

                        case SPACE:
                        case TAB:
                            break;

                        default:
                            _string.append(b);
                            _length = _string.length;
                            setState(FieldState.IN_VALUE);
                            break;
                    }
                    break;

                case FieldState.IN_VALUE:
                    switch (b) {
                        case SPACE:
                            _string.append(b);
                            break;

                        case LINE_FEED:
                            if (_length > 0) {
                                _fieldValue = takeString();
                                _length = -1;
                                _totalHeaderLineLength = -1;
                            }
                            setState(FieldState.FIELD);
                            break;

                        default:
                            _string.append(b);
                            if (b > SPACE || b < 0)
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
    private void handleField() {
        version(HUNT_DEBUG)
            tracef("parsedField:  _fieldName=%s _fieldValue=%s %s", _fieldName, _fieldValue, this);

        if (_fieldName != null && _fieldValue != null)
            _handler.parsedField(_fieldName, _fieldValue);
        _fieldName = _fieldValue = null;
    }

    /* ------------------------------------------------------------------------------- */

    protected bool parseOctetContent(ByteBuffer buffer) {

        // Starts With
        if (_partialBoundary > 0) {
            int partial = _delimiterSearch.startsWith(buffer.array(), 
                buffer.arrayOffset() + buffer.position(), buffer.remaining(), _partialBoundary);
            if (partial > 0) {
                if (partial == _delimiterSearch.getLength()) {
                    buffer.position(buffer.position() + _delimiterSearch.getLength() - _partialBoundary);
                    setState(State.DELIMITER);
                    _partialBoundary = 0;

                    version(HUNT_DEBUG)
                        tracef("Content=%s, Last=%s %s", BufferUtils.toDetailString(BufferUtils.EMPTY_BUFFER), true, this);

                    return _handler.content(BufferUtils.EMPTY_BUFFER, true);
                }

                _partialBoundary = partial;
                BufferUtils.clear(buffer);
                return false;
            } else {
                // output up to _partialBoundary of the search pattern
                ByteBuffer content = _patternBuffer.slice();
                if (_state == State.FIRST_OCTETS) {
                    setState(State.OCTETS);
                    content.position(2);
                }
                content.limit(_partialBoundary);
                _partialBoundary = 0;

                version(HUNT_DEBUG)
                    tracef("Content=%s, Last=%s %s", BufferUtils.toDetailString(content), false, this);

                if (_handler.content(content, false))
                    return true;
            }
        }

        // Contains
        int delimiter = _delimiterSearch.match(buffer.array(), buffer.arrayOffset() + buffer.position(), buffer.remaining());
        if (delimiter >= 0) {
            ByteBuffer content = buffer.slice();
            content.limit(delimiter - buffer.arrayOffset() - buffer.position());

            buffer.position(delimiter - buffer.arrayOffset() + _delimiterSearch.getLength());
            setState(State.DELIMITER);

            version(HUNT_DEBUG)
                tracef("Content=%s, Last=%s %s", BufferUtils.toDetailString(content), true, this);

            return _handler.content(content, true);
        }

        // Ends With
        _partialBoundary = _delimiterSearch.endsWith(buffer.array(), buffer.arrayOffset() + buffer.position(), buffer.remaining());
        if (_partialBoundary > 0) {
            ByteBuffer content = buffer.slice();
            content.limit(content.limit() - _partialBoundary);

            version(HUNT_DEBUG)
                tracef("Content=%s, Last=%s %s", BufferUtils.toDetailString(content), false, this);

            BufferUtils.clear(buffer);
            return _handler.content(content, false);
        }

        // There is normal content with no delimiter
        ByteBuffer content = buffer.slice();

        version(HUNT_DEBUG)
            tracef("Content=%s, Last=%s %s", BufferUtils.toDetailString(content), false, this);

        BufferUtils.clear(buffer);
        return _handler.content(content, false);
    }

    /* ------------------------------------------------------------------------------- */
    private void setState(State state) {
        version(HUNT_DEBUG)
            tracef("%s --> %s", _state, state);
        _state = state;
    }

    /* ------------------------------------------------------------------------------- */
    private void setState(FieldState state) {
        // version(HUNT_DEBUG)
        //     tracef("%s:%s --> %s", _state, _fieldState, state);
        _fieldState = state;
    }

    /* ------------------------------------------------------------------------------- */
    override
    string toString() {
        return format("%s{s=%s}", typeof(this).stringof, _state);
    }

}



/* ------------------------------------------------------------------------------- */

private class IllegalCharacterException : IllegalArgumentException {
    private this(MultiPartParser.State state, byte ch, ByteBuffer buffer) {
        super(format("Illegal character 0x%X", ch));
        // Bug #460642 - don't reveal buffers to end user
        warningf(format("Illegal character 0x%X in state=%s for buffer %s", 
            ch, state, BufferUtils.toDetailString(buffer)));
    }
}

/* ------------------------------------------------------------ */
/* ------------------------------------------------------------ */
/* ------------------------------------------------------------ */
/*
 * Event Handler interface These methods return true if the caller should process the events so far received (eg return from parseNext and call
 * HttpChannel.handle). If multiple callbacks are called in sequence (eg headerComplete then messageComplete) from the same point in the parsing then it is
 * sufficient for the caller to process the events only once.
 */
class MultiPartParserHandler {

    this() {

    }
    
    void startPart() {
    }

    void parsedField(string name, string value) {
    }

    bool headerComplete() {
        return false;
    }

    bool content(ByteBuffer item, bool last) {
        return false;
    }

    bool messageComplete() {
        return false;
    }

    void earlyEOF() {
    }
}