module hunt.http.codec.http.hpack.HpackDecoder;

import hunt.io.ByteBuffer;

import hunt.http.codec.http.hpack.AuthorityHttpField;
import hunt.http.codec.http.hpack.HpackContext;
import hunt.http.codec.http.hpack.MetaDataBuilder;
import hunt.http.codec.http.hpack.Huffman;
import hunt.http.codec.http.hpack.NBitInteger;

import hunt.http.codec.http.model;

import hunt.http.HttpField;
import hunt.http.HttpHeader;
import hunt.http.HttpMetaData;
import hunt.http.HttpRequest;
import hunt.http.HttpResponse;
import hunt.http.HttpStatus;

import hunt.text.Common;
import hunt.util.StringBuilder;
import hunt.util.ConverterUtils;
import hunt.Exceptions;

import hunt.logging;

import std.algorithm;
import std.conv;
import std.format;


alias Entry = HpackContext.Entry;

/**
 * Hpack Decoder
 * <p>
 * This is not thread safe and may only be called by 1 thread at a time.
 * </p>
 */
class HpackDecoder {
    __gshared static HttpField.LongValueHttpField CONTENT_LENGTH_0;

    shared static this()
    {
        CONTENT_LENGTH_0 = new HttpField.LongValueHttpField(HttpHeader.CONTENT_LENGTH, 0L);
    }

    private HpackContext _context;
    private MetaDataBuilder _builder;
    private int _localMaxDynamicTableSize;

    /**
     * @param localMaxDynamicTableSize The maximum allowed size of the local dynamic header field table.
     * @param maxHeaderSize            The maximum allowed size of a headers block, expressed as total of all name and value characters, plus 32 per field
     */
    this(int localMaxDynamicTableSize, int maxHeaderSize) {
        _context = new HpackContext(localMaxDynamicTableSize);
        _localMaxDynamicTableSize = localMaxDynamicTableSize;
        _builder = new MetaDataBuilder(maxHeaderSize);
    }

    HpackContext getHpackContext() {
        return _context;
    }

    void setLocalMaxDynamicTableSize(int localMaxdynamciTableSize) {
        _localMaxDynamicTableSize = localMaxdynamciTableSize;
    }

    HttpMetaData decode(ByteBuffer buffer) {
        version(HUNT_HTTP_DEBUG)
            tracef("CtxTbl[%x] decoding %d octets", _context.toHash(), buffer.remaining());

        // If the buffer is big, don't even think about decoding it
        if (buffer.remaining() > _builder.getMaxSize())
            throw new BadMessageException(HttpStatus.REQUEST_HEADER_FIELDS_TOO_LARGE_431, "Header frame size " ~ 
                to!string(buffer.remaining()) ~ ">" ~ to!string(_builder.getMaxSize()));

        while (buffer.hasRemaining()) {
            version(HUNT_HTTP_DEBUG)
            {
                if (buffer.hasArray()) {
                    int l = std.algorithm.min(buffer.remaining(), 32);
                    tracef("decode %s%s", ConverterUtils.toHexString(buffer.array(), buffer.arrayOffset() + buffer.position(), l),
                            l < buffer.remaining() ? "..." : "");
                }
            }

            byte b = buffer.get();
            if (b < 0) {
                // 7.1 indexed if the high bit is set
                int index = NBitInteger.decode(buffer, 7);
                Entry entry = _context.get(index);
                if (entry is null) {
                    throw new BadMessageException(HttpStatus.BAD_REQUEST_400, "Unknown index " ~ to!string(index));
                } else if (entry.isStatic()) {
                    version(HUNT_DEBUG)
                        tracef("decode IdxStatic %s", entry.toString());
                    // emit field
                    _builder.emit(entry.getHttpField());

                    // TODO copy and add to reference set if there is room
                    // _context.add(entry.getHttpField());
                } else {
                    version(HUNT_DEBUG)
                        tracef("decode Idx %s", entry.toString());
                    // emit
                    _builder.emit(entry.getHttpField());
                }
            } else {
                // look at the first nibble in detail
                byte f = cast(byte) ((b & 0xF0) >> 4);
                string name;
                HttpHeader header = HttpHeader.Null;
                string value;

                bool indexed;
                int name_index;

                switch (f) {
                    case 2: // 7.3
                    case 3: // 7.3
                        // change table size
                        int size = NBitInteger.decode(buffer, 5);
                        version(HUNT_DEBUG)
                            tracef("decode resize=" ~ size.to!string());
                        if (size > _localMaxDynamicTableSize)
                            throw new IllegalArgumentException("");
                        _context.resize(size);
                        continue;

                    case 0: // 7.2.2
                    case 1: // 7.2.3
                        indexed = false;
                        name_index = NBitInteger.decode(buffer, 4);
                        break;

                    case 4: // 7.2.1
                    case 5: // 7.2.1
                    case 6: // 7.2.1
                    case 7: // 7.2.1
                        indexed = true;
                        name_index = NBitInteger.decode(buffer, 6);
                        break;

                    default:
                        throw new IllegalStateException("");
                }

                bool huffmanName = false;

                // decode the name
                if (name_index > 0) {
                    Entry name_entry = _context.get(name_index);
                    name = name_entry.getHttpField().getName();
                    header = name_entry.getHttpField().getHeader();
                } else {
                    huffmanName = (buffer.get() & 0x80) == 0x80;
                    int length = NBitInteger.decode(buffer, 7);
                    _builder.checkSize(length, huffmanName);
                    if (huffmanName)
                        name = Huffman.decode(buffer, length);
                    else
                        name = toASCIIString(buffer, length);
                    for (int i = 0; i < name.length; i++) {
                        char c = name[i];
                        if (c >= 'A' && c <= 'Z') {
                            throw new BadMessageException(400, "Uppercase header name");
                        }
                    }
                    
                    header = HttpHeader.get(name);
                }

                // decode the value
                bool huffmanValue = (buffer.get() & 0x80) == 0x80;
                int length = NBitInteger.decode(buffer, 7);
                _builder.checkSize(length, huffmanValue);
                if (huffmanValue)
                    value = Huffman.decode(buffer, length);
                else
                    value = toASCIIString(buffer, length);

                version(HUNT_DEBUG){
                    tracef("header, name=%s, value=%s ", name, value);
                }


                // Make the new field
                HttpField field;
                if (header == HttpHeader.Null) {
                    // just make a normal field and bypass header name lookup
                    field = new HttpField(name, value);
                } else {
                    // might be worthwhile to create a value HttpField if it is indexed
                    // and/or of a type that may be looked up multiple times.
                    
                        if(header == HttpHeader.C_STATUS)
                        {
                            if (indexed)
                                field = new HttpField.IntValueHttpField(header, name, value);
                            else
                                field = new HttpField(header, name, value);
                        } 
                        else if(header == HttpHeader.C_AUTHORITY)
                        {
                            field = new AuthorityHttpField(value);
                        }
                        else if(header == HttpHeader.CONTENT_LENGTH) {
                            if ("0" == value)
                                field = CONTENT_LENGTH_0;
                            else
                                field = new HttpField.LongValueHttpField(header, name, value);
                        }
                        else{
                            field = new HttpField(header, name, value);
                        }
                    
                }

                 version(HUNT_DEBUG)
                {
                    tracef("decoded '%s' by %s/%s/%s",
                            field,
                            name_index > 0 ? "IdxName" : (huffmanName ? "HuffName" : "LitName"),
                            huffmanValue ? "HuffVal" : "LitVal",
                            indexed ? "Idx" : "");
                }

                // emit the field
                _builder.emit(field);

                // if indexed
                if (indexed) {
                    // add to dynamic table
                    if (_context.add(field) is null)
                        throw new BadMessageException(HttpStatus.REQUEST_HEADER_FIELDS_TOO_LARGE_431, "Indexed field value too large");
                }

            }
        }

        return _builder.build();
    }

    static string toASCIIString(ByteBuffer buffer, int length) {
        StringBuilder builder = new StringBuilder(length);
        int position = buffer.position();
        int start = buffer.arrayOffset() + position;
        int end = start + length;
        buffer.position(position + length);
        byte[] array = buffer.array();
        for (int i = start; i < end; i++)
            builder.append(cast(char) (0x7f & array[i]));
        return builder.toString();
    }

    override
    string toString() {
        return format("HpackDecoder@%x{%s}", toHash(), _context);
    }
}
