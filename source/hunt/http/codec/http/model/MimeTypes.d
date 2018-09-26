module hunt.http.codec.http.model.MimeTypes;

import hunt.http.codec.http.model.AcceptMIMEType;
import hunt.http.codec.http.model.HttpField;
import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.hpack.HpackEncoder;

import hunt.container;
import hunt.logging;

import hunt.util.Charset;
import hunt.util.exception;
import hunt.util.string;
import hunt.util.traits;

import std.algorithm;
import std.array;
import std.container.array;
import std.conv;
import std.file;
import std.path;
import std.range;
import std.stdio;
import std.string;
import std.uni;


/**
*/
class MimeTypes {

    // private __gshared static ByteBuffer[string] TYPES; // = new ArrayTrie<>(512);
    private __gshared static Map!(string, string) __dftMimeMap; 
    private __gshared static Map!(string, string) __inferredEncodings;
    private __gshared static Map!(string, string) __assumedEncodings;

    static class Type {
        __gshared Type FORM_ENCODED ;
        __gshared Type MESSAGE_HTTP ;
        __gshared Type MULTIPART_BYTERANGES ;

        __gshared Type TEXT_HTML ;
        __gshared Type TEXT_PLAIN ;
        __gshared Type TEXT_XML ;
        __gshared Type TEXT_JSON ;
        __gshared Type APPLICATION_JSON ;

        __gshared Type TEXT_HTML_8859_1 ;
        __gshared Type TEXT_HTML_UTF_8 ;

        __gshared Type TEXT_PLAIN_8859_1 ;
        __gshared Type TEXT_PLAIN_UTF_8 ;

        __gshared Type TEXT_XML_8859_1 ;
        __gshared Type TEXT_XML_UTF_8 ;

        __gshared Type TEXT_JSON_8859_1 ;
        __gshared Type TEXT_JSON_UTF_8 ;

        __gshared Type APPLICATION_JSON_8859_1 ;
        __gshared Type APPLICATION_JSON_UTF_8 ;

        __gshared Array!Type values;

        shared static this()
        {
            MESSAGE_HTTP = new Type("message/http");
            MULTIPART_BYTERANGES = new Type("multipart/byteranges");

            TEXT_HTML = new Type("text/html");
            TEXT_PLAIN = new Type("text/plain");
            TEXT_XML = new Type("text/xml");
            TEXT_JSON = new Type("text/json", StandardCharsets.UTF_8);
            APPLICATION_JSON = new Type("application/json", StandardCharsets.UTF_8);

            TEXT_HTML_8859_1 = new Type("text/html;charset=iso-8859-1", TEXT_HTML);
            TEXT_HTML_UTF_8 = new Type("text/html;charset=utf-8", TEXT_HTML);

            TEXT_PLAIN_8859_1 = new Type("text/plain;charset=iso-8859-1", TEXT_PLAIN);
            TEXT_PLAIN_UTF_8 = new Type("text/plain;charset=utf-8", TEXT_PLAIN);

            TEXT_XML_8859_1 = new Type("text/xml;charset=iso-8859-1", TEXT_XML);
            TEXT_XML_UTF_8 = new Type("text/xml;charset=utf-8", TEXT_XML);

            TEXT_JSON_8859_1 = new Type("text/json;charset=iso-8859-1", TEXT_JSON);
            TEXT_JSON_UTF_8 = new Type("text/json;charset=utf-8", TEXT_JSON);

            APPLICATION_JSON_8859_1 = new Type("application/json;charset=iso-8859-1", APPLICATION_JSON);
            APPLICATION_JSON_UTF_8 = new Type("application/json;charset=utf-8", APPLICATION_JSON);

            values.insertBack(MESSAGE_HTTP);
            values.insertBack(MULTIPART_BYTERANGES);
            values.insertBack(TEXT_HTML);
            values.insertBack(TEXT_PLAIN);
            values.insertBack(TEXT_XML);
            values.insertBack(TEXT_JSON);
            values.insertBack(APPLICATION_JSON);
            values.insertBack(TEXT_HTML_8859_1);
            values.insertBack(TEXT_HTML_UTF_8);
            values.insertBack(TEXT_PLAIN_8859_1);
            values.insertBack(TEXT_PLAIN_UTF_8);
            values.insertBack(TEXT_XML_8859_1);
            values.insertBack(TEXT_XML_UTF_8);
            values.insertBack(TEXT_JSON_8859_1);
            values.insertBack(TEXT_JSON_UTF_8);
            values.insertBack(APPLICATION_JSON_8859_1);
            values.insertBack(APPLICATION_JSON_UTF_8);
        }


        private string _string;
        private Type _base;
        private ByteBuffer _buffer;
        // private Charset _charset;
        private string _charsetString;
        private bool _assumedCharset;
        private HttpField _field;

        this(string s) {
            _string = s;
            _buffer = BufferUtils.toBuffer(s);
            _base = this;
            // _charset = null;
            _charsetString = null;
            _assumedCharset = false;
            _field = new PreEncodedHttpField(HttpHeader.CONTENT_TYPE, _string);
        }

        this(string s, Type base) {
            _string = s;
            _buffer = BufferUtils.toBuffer(s);
            _base = base;
            ptrdiff_t i = s.indexOf(";charset=");
            // _charset = Charset.forName(s.substring(i + 9));
            _charsetString = s[i + 9 .. $].toLower();
            _assumedCharset = false;
            _field = new PreEncodedHttpField(HttpHeader.CONTENT_TYPE, _string);
        }

        this(string s, string cs) {
            _string = s;
            _base = this;
            _buffer = BufferUtils.toBuffer(s);
            // _charset = cs;
            _charsetString = cs.toLower(); // _charset == null ? null : _charset.toString().toLower();
            _assumedCharset = true;
            _field = new PreEncodedHttpField(HttpHeader.CONTENT_TYPE, _string);
        }

        // ByteBuffer asBuffer() {
        //     return _buffer.asReadOnlyBuffer();
        // }

        // Charset getCharset() {
        //     return _charset;
        // }

        string getCharsetString() {
            return _charsetString;
        }

        bool isSame(string s) {
            return _string.equalsIgnoreCase(s);
        }

        string asString() {
            return _string;
        }

        override
        string toString() {
            return _string;
        }

        bool isCharsetAssumed() {
            return _assumedCharset;
        }

        HttpField getContentTypeField() {
            return _field;
        }

        // Type getBaseType() {
        //     return _base;
        // }
    }

    __gshared MimeTypes.Type[string] CACHE; 


    shared static this() {
        __dftMimeMap = new HashMap!(string, string)();
        __inferredEncodings = new HashMap!(string, string)();
        __assumedEncodings = new HashMap!(string, string)();

        foreach (MimeTypes.Type type ; MimeTypes.Type.values) {
            CACHE[type.toString()] = type;
            // TYPES[type.toString()] = type.asBuffer();

            auto charset = type.toString().indexOf(";charset=");
            if (charset > 0) {
                string alt = type.toString().replace(";charset=", "; charset=");
                CACHE[alt] = type;
                // TYPES[alt] = type.asBuffer();
            }

            if (type.isCharsetAssumed())
                __assumedEncodings.put(type.asString(), type.getCharsetString());
        }

        string resourcePath = dirName(thisExePath()) ~ "/resources";

        string resourceName = buildPath(resourcePath, "mime.properties");
        loadMimeProperties(resourceName);

        resourceName = buildPath(resourcePath, "encoding.properties");
        loadEncodingProperties(resourceName);
        
    }

    private static void loadMimeProperties(string fileName) {
        if(!exists(fileName)) {
            warningf("File does not exist: %s", fileName);
            return;
        }

        void doLoad() {
            version(HUNT_DEBUG) tracef("loading MIME properties from: %s", fileName);
            try {
                File f = File(fileName, "r");
                scope(exit) f.close();
                string line;
                int count = 0;
                while((line = f.readln()) !is null) {
                    string[] parts = split(line, "=");
                    if(parts.length < 2) continue;

                    count++;
                    string key = parts[0].strip().toLower();
                    string value = normalizeMimeType(parts[1].strip());
                    // trace(key, " = ", value);
                    __dftMimeMap.put(key, value);
                }

                if (__dftMimeMap.size() == 0) {
                    warningf("Empty mime types at %s", fileName);
                } else if (__dftMimeMap.size() < count) {
                    warningf("Duplicate or null mime-type extension in resource: %s", fileName);
                }            
            } catch(Exception ex) {
                warningf(ex.toString());
            }
        }

        doLoad();
        // import std.parallelism;
        // auto t = task(&doLoad);
        // t.executeInNewThread();
    }

    private static void loadEncodingProperties(string fileName) {
        if(!exists(fileName)) {
            warningf("File does not exist: %s", fileName);
            return;
        }

        version(HUNT_DEBUG) tracef("loading MIME properties from: %s", fileName);
        try {
            File f = File(fileName, "r");
            scope(exit) f.close();
            string line;
            int count = 0;
            while((line = f.readln()) !is null) {
                string[] parts = split(line, "=");
                if(parts.length < 2) continue;

                count++;
                string t = parts[0].strip();
                string charset = parts[1].strip();
                trace(t, " = ", charset);
                if(charset.startsWith("-"))
                    __assumedEncodings.put(t, charset[1..$]);
                else
                    __inferredEncodings.put(t, charset);
            }

            if (__inferredEncodings.size() == 0) {
                warningf("Empty encodings at %s", fileName);
            } else if (__inferredEncodings.size() + __inferredEncodings.size() < count) {
                warningf("Null or duplicate encodings in resource: %s", fileName);
            }            
        } catch(Exception ex) {
            warningf(ex.toString());
        }
    }

    /**
     * Constructor.
     */
    this() {
    }

    Map!(string, string) getMimeMap() {
        if(_mimeMap is null)
            _mimeMap = new HashMap!(string, string)();
        return _mimeMap;
    }

    private Map!(string, string) _mimeMap; 

    /**
     * @param mimeMap A Map of file extension to mime-type.
     */
    void setMimeMap(Map!(string, string) mimeMap) {
        _mimeMap.clear();
        if (mimeMap !is null) {
            foreach (string k, string v ; mimeMap)
                _mimeMap.put(std.uni.toLower(k), normalizeMimeType(v));
        }
    }

    /**
     * Get the MIME type by filename extension.
     * Lookup only the static default mime map.
     *
     * @param filename A file name
     * @return MIME type matching the longest dot extension of the
     * file name.
     */
    static string getDefaultMimeByExtension(string filename) {
        string type = null;

        if (filename != null) {
            ptrdiff_t i = -1;
            while (type == null) {
                i = filename.indexOf(".", i + 1);

                if (i < 0 || i >= filename.length)
                    break;

                string ext = std.uni.toLower(filename[i + 1 .. $]);
                if (type == null)
                    type = __dftMimeMap.get(ext);
            }
        }

        if (type == null) {
            if (type == null)
                type = __dftMimeMap.get("*");
        }

        return type;
    }

    /**
     * Get the MIME type by filename extension.
     * Lookup the content and static default mime maps.
     *
     * @param filename A file name
     * @return MIME type matching the longest dot extension of the
     * file name.
     */
    string getMimeByExtension(string filename) {
        string type = null;

        if (filename != null) {
            ptrdiff_t i = -1;
            while (type == null) {
                i = filename.indexOf(".", i + 1);

                if (i < 0 || i >= filename.length)
                    break;

                string ext = std.uni.toLower(filename[i + 1 .. $]);
                if (_mimeMap !is null)
                    type = _mimeMap.get(ext);
                if (type == null)
                    type = __dftMimeMap.get(ext);
            }
        }

        if (type == null) {
            if (_mimeMap !is null)
                type = _mimeMap.get("*");
            if (type == null)
                type = __dftMimeMap.get("*");
        }

        return type;
    }

    /**
     * Set a mime mapping
     *
     * @param extension the extension
     * @param type      the mime type
     */
    void addMimeMapping(string extension, string type) {
        _mimeMap.put(std.uni.toLower(extension), normalizeMimeType(type));
    }

    static Set!string getKnownMimeTypes() {
        auto hs = new HashSet!(string)();
        foreach(v ; __dftMimeMap.values())
            hs.add(v);
        return hs;
    }

    private static string normalizeMimeType(string type) {
        MimeTypes.Type t = CACHE.get(type, null);
        if (t !is null)
            return t.asString();

        return std.uni.toLower(type);
    }

    static string getCharsetFromContentType(string value) {
        if (value == null)
            return null;
        int end = cast(int)value.length;
        int state = 0;
        int start = 0;
        bool quote = false;
        int i = 0;
        for (; i < end; i++) {
            char b = value[i];

            if (quote && state != 10) {
                if ('"' == b)
                    quote = false;
                continue;
            }

            if (';' == b && state <= 8) {
                state = 1;
                continue;
            }

            switch (state) {
                case 0:
                    if ('"' == b) {
                        quote = true;
                        break;
                    }
                    break;

                case 1:
                    if ('c' == b) state = 2;
                    else if (' ' != b) state = 0;
                    break;
                case 2:
                    if ('h' == b) state = 3;
                    else state = 0;
                    break;
                case 3:
                    if ('a' == b) state = 4;
                    else state = 0;
                    break;
                case 4:
                    if ('r' == b) state = 5;
                    else state = 0;
                    break;
                case 5:
                    if ('s' == b) state = 6;
                    else state = 0;
                    break;
                case 6:
                    if ('e' == b) state = 7;
                    else state = 0;
                    break;
                case 7:
                    if ('t' == b) state = 8;
                    else state = 0;
                    break;

                case 8:
                    if ('=' == b) state = 9;
                    else if (' ' != b) state = 0;
                    break;

                case 9:
                    if (' ' == b)
                        break;
                    if ('"' == b) {
                        quote = true;
                        start = i + 1;
                        state = 10;
                        break;
                    }
                    start = i;
                    state = 10;
                    break;

                case 10:
                    if (!quote && (';' == b || ' ' == b) ||
                            (quote && '"' == b))
                        return StringUtils.normalizeCharset(value, start, i - start);
                    break;

                default: break;
            }
        }

        if (state == 10)
            return StringUtils.normalizeCharset(value, start, i - start);

        return null;
    }

    /**
     * Access a mutable map of mime type to the charset inferred from that content type.
     * An inferred encoding is used by when encoding/decoding a stream and is
     * explicitly set in any metadata (eg Content-Type).
     *
     * @return Map of mime type to charset
     */
    static Map!(string, string) getInferredEncodings() {
        return __inferredEncodings;
    }

    /**
     * Access a mutable map of mime type to the charset assumed for that content type.
     * An assumed encoding is used by when encoding/decoding a stream, but is not
     * explicitly set in any metadata (eg Content-Type).
     *
     * @return Map of mime type to charset
     */
    static Map!(string, string) getAssumedEncodings() {
        return __inferredEncodings;
    }

    deprecated("")
    static string inferCharsetFromContentType(string contentType) {
        return getCharsetAssumedFromContentType(contentType);
    }

    static string getCharsetInferredFromContentType(string contentType) {
        return __inferredEncodings.get(contentType);
    }

    static string getCharsetAssumedFromContentType(string contentType) {
        return __assumedEncodings.get(contentType);
    }

    static string getContentTypeWithoutCharset(string value) {
        int end = cast(int)value.length;
        int state = 0;
        int start = 0;
        bool quote = false;
        int i = 0;
        StringBuilder builder = null;
        for (; i < end; i++) {
            char b = value[i];

            if ('"' == b) {
                quote = !quote;

                switch (state) {
                    case 11:
                        builder.append(b);
                        break;
                    case 10:
                        break;
                    case 9:
                        builder = new StringBuilder();
                        builder.append(value, 0, start + 1);
                        state = 10;
                        break;
                    default:
                        start = i;
                        state = 0;
                }
                continue;
            }

            if (quote) {
                if (builder !is null && state != 10)
                    builder.append(b);
                continue;
            }

            switch (state) {
                case 0:
                    if (';' == b)
                        state = 1;
                    else if (' ' != b)
                        start = i;
                    break;

                case 1:
                    if ('c' == b) state = 2;
                    else if (' ' != b) state = 0;
                    break;
                case 2:
                    if ('h' == b) state = 3;
                    else state = 0;
                    break;
                case 3:
                    if ('a' == b) state = 4;
                    else state = 0;
                    break;
                case 4:
                    if ('r' == b) state = 5;
                    else state = 0;
                    break;
                case 5:
                    if ('s' == b) state = 6;
                    else state = 0;
                    break;
                case 6:
                    if ('e' == b) state = 7;
                    else state = 0;
                    break;
                case 7:
                    if ('t' == b) state = 8;
                    else state = 0;
                    break;
                case 8:
                    if ('=' == b) state = 9;
                    else if (' ' != b) state = 0;
                    break;

                case 9:
                    if (' ' == b)
                        break;
                    builder = new StringBuilder();
                    builder.append(value, 0, start + 1);
                    state = 10;
                    break;

                case 10:
                    if (';' == b) {
                        builder.append(b);
                        state = 11;
                    }
                    break;

                case 11:
                    if (' ' != b)
                        builder.append(b);
                    break;
                
                default: break;
            }
        }
        if (builder is null)
            return value;
        return builder.toString();

    }

    static string getContentTypeMIMEType(string contentType) {
        if (contentType.empty) 
            return null;

        // parsing content-type
        string[] strings = StringUtils.split(contentType, ";");
        return strings[0];
    }

    static List!string getAcceptMIMETypes(string accept) {
        if(accept.empty) 
            new EmptyList!string(); // Collections.emptyList();

        List!string list = new ArrayList!string();
        // parsing accept
        string[] strings = StringUtils.split(accept, ",");
        foreach (string str ; strings) {
            string[] s = StringUtils.split(str, ";");
            list.add(s[0].strip());
        }
        return list;
    }

    static AcceptMIMEType[] parseAcceptMIMETypes(string accept) {

        if(accept.empty) 
            return [];

        string[] arr = StringUtils.split(accept, ",");
        return apply(arr);
    }

    private static AcceptMIMEType[] apply(string[] stream) {

        Array!AcceptMIMEType arr;

        foreach(string s; stream) {
            string type = strip(s);
            if(type.empty) continue;
            string[] mimeTypeAndQuality = StringUtils.split(type, ';');
            AcceptMIMEType acceptMIMEType = new AcceptMIMEType();
            
            // parse the MIME type
            string[] mimeType = StringUtils.split(mimeTypeAndQuality[0].strip(), '/');
            string parentType = mimeType[0].strip();
            string childType = mimeType[1].strip();
            acceptMIMEType.setParentType(parentType);
            acceptMIMEType.setChildType(childType);
            if (parentType == "*") {
                if (childType == "*") {
                    acceptMIMEType.setMatchType(AcceptMIMEMatchType.ALL);
                } else {
                    acceptMIMEType.setMatchType(AcceptMIMEMatchType.CHILD);
                }
            } else {
                if (childType == "*") {
                    acceptMIMEType.setMatchType(AcceptMIMEMatchType.PARENT);
                } else {
                    acceptMIMEType.setMatchType(AcceptMIMEMatchType.EXACT);
                }
            }

            // parse the quality
            if (mimeTypeAndQuality.length > 1) {
                string q = mimeTypeAndQuality[1];
                string[] qualityKV = StringUtils.split(q, '=');
                acceptMIMEType.setQuality(to!float(qualityKV[1].strip()));
            }
            arr.insertBack(acceptMIMEType);
        }

        for(size_t i=0; i<arr.length-1; i++) {
            for(size_t j=i+1; j<arr.length; j++) {
                AcceptMIMEType a = arr[i];
                AcceptMIMEType b = arr[j];
                if(b.getQuality() > a.getQuality()) {   // The greater quality is first.
                    arr[i] = b; arr[j] = a;
                }
            }
        }

        return arr.array();
    }
}
