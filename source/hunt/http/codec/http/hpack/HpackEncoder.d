module hunt.http.codec.http.hpack.HpackEncoder;

import hunt.http.codec.http.hpack.HpackContext;
import hunt.http.codec.http.hpack.Huffman;
import hunt.http.codec.http.hpack.NBitInteger;

// import hunt.http.codec.http.model;

import hunt.http.codec.http.model.HttpField;
import hunt.http.codec.http.model.HttpFields;
import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.model.HttpStatus;
import hunt.http.codec.http.model.HttpScheme;
import hunt.http.HttpVersion;
import hunt.http.codec.http.model.MetaData;

import hunt.collection.ByteBuffer;
import hunt.collection.BufferUtils;

import hunt.http.codec.http.encode.Http1FieldPreEncoder;
import hunt.http.codec.http.encode.HttpFieldPreEncoder;
import hunt.http.codec.http.hpack.NBitInteger;
import hunt.http.codec.http.hpack.Huffman;
import hunt.http.codec.http.hpack.HpackContext;

// import hunt.http.codec.http.model.HttpHeader;
// import hunt.http.HttpVersion;

import hunt.Exceptions;
import hunt.util.ConverterUtils;


// import hunt.http.codec.http.model.HttpField;
// import hunt.http.codec.http.model.HttpHeader;
// import hunt.http.HttpVersion;

import hunt.logging;

import std.range;
import std.algorithm;
import std.conv;

alias Entry = HpackContext.Entry;
alias StaticEntry = HpackContext.StaticEntry;

/**
*/
class HpackEncoder {

    private __gshared static HttpField[599] __status;

    enum HttpHeader[] __DO_NOT_HUFFMAN = [            
                    HttpHeader.AUTHORIZATION,
                    HttpHeader.CONTENT_MD5,
                    HttpHeader.PROXY_AUTHENTICATE,
                    HttpHeader.PROXY_AUTHORIZATION];

    enum HttpHeader[] __DO_NOT_INDEX = [
                    // HttpHeader.C_PATH,  // TODO more data needed
                    // HttpHeader.DATE,    // TODO more data needed
                    HttpHeader.AUTHORIZATION,
                    HttpHeader.CONTENT_MD5,
                    HttpHeader.CONTENT_RANGE,
                    HttpHeader.ETAG,
                    HttpHeader.IF_MODIFIED_SINCE,
                    HttpHeader.IF_UNMODIFIED_SINCE,
                    HttpHeader.IF_NONE_MATCH,
                    HttpHeader.IF_RANGE,
                    HttpHeader.IF_MATCH,
                    HttpHeader.LOCATION,
                    HttpHeader.RANGE,
                    HttpHeader.RETRY_AFTER,
                    // HttpHeader.EXPIRES,
                    HttpHeader.LAST_MODIFIED,
                    HttpHeader.SET_COOKIE,
                    HttpHeader.SET_COOKIE2];


    enum HttpHeader[] __NEVER_INDEX = [
                    HttpHeader.AUTHORIZATION,
                    HttpHeader.SET_COOKIE,
                    HttpHeader.SET_COOKIE2];

    shared static this() {
        foreach (HttpStatus.Code code ; HttpStatus.Code.values())
            __status[code.getCode()] = new PreEncodedHttpField(HttpHeader.C_STATUS, std.conv.to!(string)(code.getCode()));
    }

    private HpackContext _context;
    private bool _debug;
    private int _remoteMaxDynamicTableSize;
    private int _localMaxDynamicTableSize;
    private int _maxHeaderListSize;
    private int _headerListSize;

    this() {
        this(4096, 4096, -1);
    }

    this(int localMaxDynamicTableSize) {
        this(localMaxDynamicTableSize, 4096, -1);
    }

    this(int localMaxDynamicTableSize, int remoteMaxDynamicTableSize) {
        this(localMaxDynamicTableSize, remoteMaxDynamicTableSize, -1);
    }

    this(int localMaxDynamicTableSize, int remoteMaxDynamicTableSize, int maxHeaderListSize) {
        _context = new HpackContext(remoteMaxDynamicTableSize);
        _remoteMaxDynamicTableSize = remoteMaxDynamicTableSize;
        _localMaxDynamicTableSize = localMaxDynamicTableSize;
        _maxHeaderListSize = maxHeaderListSize;
        _debug = true; //log.isDebugEnabled();
    }

    int getMaxHeaderListSize() {
        return _maxHeaderListSize;
    }

    void setMaxHeaderListSize(int maxHeaderListSize) {
        _maxHeaderListSize = maxHeaderListSize;
    }

    HpackContext getHpackContext() {
        return _context;
    }

    void setRemoteMaxDynamicTableSize(int remoteMaxDynamicTableSize) {
        _remoteMaxDynamicTableSize = remoteMaxDynamicTableSize;
    }

    void setLocalMaxDynamicTableSize(int localMaxDynamicTableSize) {
        _localMaxDynamicTableSize = localMaxDynamicTableSize;
    }

    void encode(ByteBuffer buffer, MetaData metadata) {
        version(HUNT_DEBUG)
            tracef("CtxTbl[%x] encoding", _context.toHash());

        _headerListSize = 0;
        int pos = buffer.position();

        // Check the dynamic table sizes!
        int maxDynamicTableSize = std.algorithm.min(_remoteMaxDynamicTableSize, _localMaxDynamicTableSize);
        if (maxDynamicTableSize != _context.getMaxDynamicTableSize())
            encodeMaxDynamicTableSize(buffer, maxDynamicTableSize);

        // Add Request/response meta fields
        if (metadata.isRequest()) {
            HttpRequest request = cast(HttpRequest) metadata;

            // TODO optimise these to avoid HttpField creation
            string scheme = request.getURI().getScheme();
            encode(buffer, new HttpField(HttpHeader.C_SCHEME, scheme.empty ? HttpScheme.HTTP : scheme));
            encode(buffer, new HttpField(HttpHeader.C_METHOD, request.getMethod()));
            encode(buffer, new HttpField(HttpHeader.C_AUTHORITY, request.getURI().getAuthority()));
            encode(buffer, new HttpField(HttpHeader.C_PATH, request.getURI().getPathQuery()));
        } else if (metadata.isResponse()) {
            HttpResponse response = cast(HttpResponse) metadata;
            int code = response.getStatus();
            HttpField status = code < __status.length ? __status[code] : null;
            if (status is null)
                status = new HttpField.IntValueHttpField(HttpHeader.C_STATUS, code);
            encode(buffer, status);
        }

        // Add all the other fields
        foreach (HttpField field ; metadata)
            encode(buffer, field);

        // Check size
        if (_maxHeaderListSize > 0 && _headerListSize > _maxHeaderListSize) {
            warningf("Header list size too large %s > %s for %s", _headerListSize, _maxHeaderListSize);
            version(HUNT_DEBUG)
                tracef("metadata=%s", metadata);
        }

        version(HUNT_DEBUG)
            tracef("CtxTbl[%x] encoded %d octets", _context.toHash(), buffer.position() - pos);
    }

    void encodeMaxDynamicTableSize(ByteBuffer buffer, int maxDynamicTableSize) {
        if (maxDynamicTableSize > _remoteMaxDynamicTableSize)
            throw new IllegalArgumentException("");
        buffer.put(cast(byte) 0x20);
        NBitInteger.encode(buffer, 5, maxDynamicTableSize);
        _context.resize(maxDynamicTableSize);
    }

    void encode(ByteBuffer buffer, HttpField field) {
        if (field.getValue() == null)
            field = new HttpField(field.getHeader(), field.getName(), "");

        int field_size = cast(int)(field.getName().length + field.getValue().length);
        _headerListSize += field_size + 32;

        int p = _debug ? buffer.position() : -1;
        string encoding = null;

        HttpHeader he = field.getHeader();
        // tracef("encoding: %s,  hash: %d", field.toString(), field.toHash());

        // Is there an entry for the field?
        Entry entry = _context.get(field);
        if (entry !is null) {
            // Known field entry, so encode it as indexed
            if (entry.isStatic()) {
                buffer.put((cast(StaticEntry) entry).getEncodedField());
                version(HUNT_DEBUG)
                    encoding = "IdxFieldS1";
            } else {
                int index = _context.index(entry);
                buffer.put(cast(byte) 0x80);
                NBitInteger.encode(buffer, 7, index);
                version(HUNT_DEBUG)
                    encoding = "IdxField" ~ (entry.isStatic() ? "S" : "") ~ to!string(1 + NBitInteger.octectsNeeded(7, index));
            }
        } else {
            // Unknown field entry, so we will have to send literally.
            bool indexed;

            // But do we know it's name?
            HttpHeader header = field.getHeader();

            // Select encoding strategy
            if (header == HttpHeader.Null) {
                // Select encoding strategy for unknown header names
                Entry name = _context.get(field.getName());

                if (typeid(field) == typeid(PreEncodedHttpField)) {
                    int i = buffer.position();
                    (cast(PreEncodedHttpField) field).putTo(buffer, HttpVersion.HTTP_2);
                    byte b = buffer.get(i);
                    indexed = b < 0 || b >= 0x40;
                    version(HUNT_DEBUG)
                        encoding = indexed ? "PreEncodedIdx" : "PreEncoded";
                }
                // has the custom header name been seen before?
                else if (name is null) {
                    // unknown name and value, so let's index this just in case it is
                    // the first time we have seen a custom name or a custom field.
                    // unless the name is changing, this is worthwhile
                    indexed = true;
                    encodeName(buffer, cast(byte) 0x40, 6, field.getName(), null);
                    encodeValue(buffer, true, field.getValue());
                    version(HUNT_DEBUG)
                        encoding = "LitHuffNHuffVIdx";
                } else {
                    // known custom name, but unknown value.
                    // This is probably a custom field with changing value, so don't index.
                    indexed = false;
                    encodeName(buffer, cast(byte) 0x00, 4, field.getName(), null);
                    encodeValue(buffer, true, field.getValue());
                    version(HUNT_DEBUG)
                        encoding = "LitHuffNHuffV!Idx";
                }
            } else {
                // Select encoding strategy for known header names
                Entry name = _context.get(header);
                if(name is null)
                    warningf("no entry found for header: %s", header.toString());
                // else
                //     tracef("Entry=%s, header: name=%s, ordinal=%d", name.toString(), header.toString(), header.ordinal());

                if (typeid(field) == typeid(PreEncodedHttpField)) {
                    // Preencoded field
                    int i = buffer.position();
                    (cast(PreEncodedHttpField) field).putTo(buffer, HttpVersion.HTTP_2);
                    byte b = buffer.get(i);
                    indexed = b < 0 || b >= 0x40;
                    version(HUNT_DEBUG)
                        encoding = indexed ? "PreEncodedIdx" : "PreEncoded";
                } else if (__DO_NOT_INDEX.contains(header)) {
                    // Non indexed field
                    indexed = false;
                    bool never_index = __NEVER_INDEX.contains(header);
                    bool huffman = !__DO_NOT_HUFFMAN.contains(header);
                    encodeName(buffer, never_index ? cast(byte) 0x10 : cast(byte) 0x00, 4, header.asString(), name);
                    encodeValue(buffer, huffman, field.getValue());

                    version(HUNT_DEBUG)
                    {
                        encoding = "Lit" ~ ((name is null) ? "HuffN" : ("IdxN" ~ (name.isStatic() ? "S" : "") ~ 
                                to!string(1 + NBitInteger.octectsNeeded(4, _context.index(name))))) ~
                                (huffman ? "HuffV" : "LitV") ~
                                (indexed ? "Idx" : (never_index ? "!!Idx" : "!Idx"));
                        
                    }
                } else if (field_size >= _context.getMaxDynamicTableSize() || header == HttpHeader.CONTENT_LENGTH &&
                 field.getValue().length > 2) {
                    // Non indexed if field too large or a content length for 3 digits or more
                    indexed = false;
                    encodeName(buffer, cast(byte) 0x00, 4, header.asString(), name);
                    encodeValue(buffer, true, field.getValue());
                    version(HUNT_DEBUG)
                        encoding = "LitIdxNS" ~ to!string(1 + NBitInteger.octectsNeeded(4, _context.index(name))) ~ "HuffV!Idx";
                } else {
                    // indexed
                    indexed = true;
                    bool huffman = !__DO_NOT_HUFFMAN.contains(header);
                    encodeName(buffer, cast(byte) 0x40, 6, header.asString(), name);
                    encodeValue(buffer, huffman, field.getValue());
                    version(HUNT_DEBUG){
                        encoding = ((name is null) ? "LitHuffN" : ("LitIdxN" ~ (name.isStatic() ? "S" : "") ~ 
                        to!string(1 + NBitInteger.octectsNeeded(6, _context.index(name))))) ~
                                (huffman ? "HuffVIdx" : "LitVIdx");
                    }
                }
            }

            // If we want the field referenced, then we add it to our
            // table and reference set.
            if (indexed)
                if (_context.add(field) is null)
                    throw new IllegalStateException("");
        }

        version(HUNT_HTTP_DEBUG) 
        {
            int e = buffer.position();
            tracef("encode %s:'%s' to '%s'", encoding, field, 
                ConverterUtils.toHexString(buffer.array(), buffer.arrayOffset() + p, e - p));
        }
    }

    private void encodeName(ByteBuffer buffer, byte mask, int bits, string name, Entry entry) {
        buffer.put(mask);
        if (entry is null) {
            // leave name index bits as 0
            // Encode the name always with lowercase huffman
            buffer.put(cast(byte) 0x80);
            NBitInteger.encode(buffer, 7, Huffman.octetsNeededLC(name));
            Huffman.encodeLC(buffer, name);
        } else {
            NBitInteger.encode(buffer, bits, _context.index(entry));
        }
    }

    static void encodeValue(ByteBuffer buffer, bool huffman, string value) {
        if (huffman) {
            // huffman literal value
            buffer.put(cast(byte) 0x80);
            NBitInteger.encode(buffer, 7, Huffman.octetsNeeded(value));
            Huffman.encode(buffer, value);
        } else {
            // add literal assuming iso_8859_1
            buffer.put(cast(byte) 0x00);
            NBitInteger.encode(buffer, 7, cast(int)value.length);
            for (size_t i = 0; i < value.length; i++) {
                char c = value[i];
                if (c < ' ' || c > 127)
                    throw new IllegalArgumentException("");
                buffer.put(cast(byte) c);
            }
        }
    }
}


/**
*/
class HpackFieldPreEncoder : HttpFieldPreEncoder {

	override
	HttpVersion getHttpVersion() {
		return HttpVersion.HTTP_2;
	}

	override
	byte[] getEncodedField(HttpHeader header, string name, string value) {
		bool not_indexed = HpackEncoder.__DO_NOT_INDEX.contains(header);

		ByteBuffer buffer = BufferUtils.allocate(cast(int) (name.length + value.length + 10));
		BufferUtils.clearToFill(buffer);
		bool huffman;
		int bits;

		if (not_indexed) {
			// Non indexed field
			bool never_index = HpackEncoder.__NEVER_INDEX.contains(header);
			huffman = !HpackEncoder.__DO_NOT_HUFFMAN.contains(header);
			buffer.put(never_index ? cast(byte) 0x10 : cast(byte) 0x00);
			bits = 4;
		} else if (header == HttpHeader.CONTENT_LENGTH && value.length > 1) {
			// Non indexed content length for 2 digits or more
			buffer.put(cast(byte) 0x00);
			huffman = true;
			bits = 4;
		} else {
			// indexed
			buffer.put(cast(byte) 0x40);
			huffman = !HpackEncoder.__DO_NOT_HUFFMAN.contains(header);
			bits = 6;
		}

		int name_idx = HpackContext.staticIndex(header);
		if (name_idx > 0)
			NBitInteger.encode(buffer, bits, name_idx);
		else {
			buffer.put(cast(byte) 0x80);
			NBitInteger.encode(buffer, 7, Huffman.octetsNeededLC(name));
			Huffman.encodeLC(buffer, name);
		}

		HpackEncoder.encodeValue(buffer, huffman, value);

		BufferUtils.flipToFlush(buffer, 0);
		return BufferUtils.toArray(buffer);
	}
}


/**
 * Pre encoded HttpField.
 * <p>A HttpField that will be cached and used many times can be created as
 * a {@link PreEncodedHttpField}, which will use the {@link HttpFieldPreEncoder}
 * instances discovered by the {@link ServiceLoader} to pre-encode the header
 * for each version of HTTP in use.  This will save garbage
 * and CPU each time the field is encoded into a response.
 * </p>
 */
class PreEncodedHttpField : HttpField {
    private __gshared static HttpFieldPreEncoder[] __encoders;

    private byte[][] _encodedField = new byte[][2];

    shared static this()
    {
        __encoders ~= new HpackFieldPreEncoder();
        __encoders ~= new Http1FieldPreEncoder();
        // __encoders = [ null,
        //     new Http1FieldPreEncoder()];
    }

    this(HttpHeader header, string name, string value) {
        super(header, name, value);

        foreach (HttpFieldPreEncoder e ; __encoders) {
            if(e is null)
                continue;
            _encodedField[e.getHttpVersion() == HttpVersion.HTTP_2 ? 1 : 0] = e.getEncodedField(header, header.asString(), value);
        }
    }

    this(HttpHeader header, string value) {
        this(header, header.asString(), value);
    }

    this(string name, string value) {
        this(HttpHeader.Null, name, value);
    }

    void putTo(ByteBuffer bufferInFillMode, HttpVersion ver) {
        bufferInFillMode.put(_encodedField[ver == HttpVersion.HTTP_2 ? 1 : 0]);
    }
}