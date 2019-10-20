module hunt.http.codec.http.model.HttpTokens;

/**
 * HTTP constants
 */
struct HttpTokens
{
    // Terminal symbols.
    enum byte COLON = ':';
    enum byte TAB = 0x09;
    enum byte LINE_FEED = 0x0A;
    enum byte CARRIAGE_RETURN = 0x0D;
    enum byte SPACE = 0x20;
    enum byte[] CRLF = [CARRIAGE_RETURN, LINE_FEED];
    enum byte SEMI_COLON = ';';

}

enum EndOfContent
{
    UNKNOWN_CONTENT,
    NO_CONTENT,
    EOF_CONTENT,
    CONTENT_LENGTH,
    CHUNKED_CONTENT
}
