module hunt.http.codec.http.hpack.HpackContext;

// import hunt.http.codec.http.model;

import hunt.http.codec.http.model.HttpField;
import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.model.HttpMethod;
import hunt.http.codec.http.model.StaticTableHttpField;

import hunt.http.codec.http.hpack.Huffman;
import hunt.http.codec.http.hpack.NBitInteger;

import hunt.util.exception;
import hunt.util.string;
import hunt.container;

import hunt.logger;

import std.array;
import std.conv;
import std.uni;
import std.format;

/**
 * HPACK - Header Compression for HTTP/2
 * <p>
 * This class maintains the compression context for a single HTTP/2 connection.
 * Specifically it holds the static and dynamic Header Field Tables and the
 * associated sizes and limits.
 * </p>
 * <p>
 * It is compliant with draft 11 of the specification
 * </p>
 */
class HpackContext {

    
    private enum string EMPTY = "";
    enum string[][] STATIC_TABLE =
        [
                [null, null],
        /* 1  */ [":authority", EMPTY],
        /* 2  */ [":method", "GET"],
        /* 3  */ [":method", "POST"],
        /* 4  */ [":path", "/"],
        /* 5  */ [":path", "/index.html"],
        /* 6  */ [":scheme", "http"],
        /* 7  */ [":scheme", "https"],
        /* 8  */ [":status", "200"],
        /* 9  */ [":status", "204"],
        /* 10 */ [":status", "206"],
        /* 11 */ [":status", "304"],
        /* 12 */ [":status", "400"],
        /* 13 */ [":status", "404"],
        /* 14 */ [":status", "500"],
        /* 15 */ ["accept-charset", EMPTY],
        /* 16 */ ["accept-encoding", "gzip, deflate"],
        /* 17 */ ["accept-language", EMPTY],
        /* 18 */ ["accept-ranges", EMPTY],
        /* 19 */ ["accept", EMPTY],
        /* 20 */ ["access-control-allow-origin", EMPTY],
        /* 21 */ ["age", EMPTY],
        /* 22 */ ["allow", EMPTY],
        /* 23 */ ["authorization", EMPTY],
        /* 24 */ ["cache-control", EMPTY],
        /* 25 */ ["content-disposition", EMPTY],
        /* 26 */ ["content-encoding", EMPTY],
        /* 27 */ ["content-language", EMPTY],
        /* 28 */ ["content-length", EMPTY],
        /* 29 */ ["content-location", EMPTY],
        /* 30 */ ["content-range", EMPTY],
        /* 31 */ ["content-type", EMPTY],
        /* 32 */ ["cookie", EMPTY],
        /* 33 */ ["date", EMPTY],
        /* 34 */ ["etag", EMPTY],
        /* 35 */ ["expect", EMPTY],
        /* 36 */ ["expires", EMPTY],
        /* 37 */ ["from", EMPTY],
        /* 38 */ ["host", EMPTY],
        /* 39 */ ["if-match", EMPTY],
        /* 40 */ ["if-modified-since", EMPTY],
        /* 41 */ ["if-none-match", EMPTY],
        /* 42 */ ["if-range", EMPTY],
        /* 43 */ ["if-unmodified-since", EMPTY],
        /* 44 */ ["last-modified", EMPTY],
        /* 45 */ ["link", EMPTY],
        /* 46 */ ["location", EMPTY],
        /* 47 */ ["max-forwards", EMPTY],
        /* 48 */ ["proxy-authenticate", EMPTY],
        /* 49 */ ["proxy-authorization", EMPTY],
        /* 50 */ ["range", EMPTY],
        /* 51 */ ["referer", EMPTY],
        /* 52 */ ["refresh", EMPTY],
        /* 53 */ ["retry-after", EMPTY],
        /* 54 */ ["server", EMPTY],
        /* 55 */ ["set-cookie", EMPTY],
        /* 56 */ ["strict-transport-security", EMPTY],
        /* 57 */ ["transfer-encoding", EMPTY],
        /* 58 */ ["user-agent", EMPTY],
        /* 59 */ ["vary", EMPTY],
        /* 60 */ ["via", EMPTY],
        /* 61 */ ["www-authenticate", EMPTY]
        ];

    private __gshared static Entry[HttpField] __staticFieldMap; // = new HashMap<>();
    private __gshared static StaticEntry[string] __staticNameMap; // = new ArrayTernaryTrie<>(true, 512);
    private __gshared static StaticEntry[int] __staticTableByHeader; // = new StaticEntry[HttpHeader.getCount];
    private __gshared static StaticEntry[] __staticTable; // = new StaticEntry[STATIC_TABLE.length];
    enum int STATIC_SIZE = cast(int)STATIC_TABLE.length - 1;

    shared static this() {
        // __staticTableByHeader = new StaticEntry[HttpHeader.getCount];
        __staticTable = new StaticEntry[STATIC_TABLE.length];

        Set!string added = new HashSet!(string)();
        for (int i = 1; i < STATIC_TABLE.length; i++) {
            StaticEntry entry = null;

            string name = STATIC_TABLE[i][0];
            string value = STATIC_TABLE[i][1];
            // HttpHeader header = HttpHeader.CACHE[name];
            HttpHeader header = HttpHeader.get(name);
            if (header != HttpHeader.Null && !value.empty) {
                    if(header == HttpHeader.C_METHOD) {
                        HttpMethod method = HttpMethod.CACHE[value];
                        if (method != HttpMethod.Null)
                            entry = new StaticEntry(i, new StaticTableHttpField!(HttpMethod)(header, name, value, method));
                    }
                    else if(header == HttpHeader.C_SCHEME) {

                        // HttpScheme scheme = HttpScheme.CACHE.get(value);
                        string scheme = value;
                        if (!scheme.empty)
                            entry = new StaticEntry(i, new StaticTableHttpField!(string)(header, name, value, scheme));
                    }
                    else if(header == HttpHeader.C_STATUS) {
                        entry = new StaticEntry(i, new StaticTableHttpField!(string)(header, name, value, (value)));
                    }
            }
            else
            {
                // warning("name=>", name, ", length=", HttpHeader.CACHE.length);
            }

            if (entry is null)
                entry = new StaticEntry(i, header == HttpHeader.Null ? new HttpField(STATIC_TABLE[i][0], value) : new HttpField(header, name, value));

            __staticTable[i] = entry;

            HttpField currentField = entry._field;
            string fieldName = currentField.getName().toLower();
            string fieldValue = currentField.getValue();
            if (fieldValue !is null)
            {
                // tracef("%s,  hash: %d", currentField.toString(), currentField.toHash());
                __staticFieldMap[currentField] = entry;
            }
            else
            {
                warning("Empty field: ", currentField.toString());    
            }

            if (!added.contains(fieldName)) {
                added.add(fieldName);
                __staticNameMap[fieldName] = entry;
                // if (__staticNameMap[fieldName] is null)
                //     throw new IllegalStateException("name trie too small");
            }
        }

        // trace(__staticNameMap);

        foreach (HttpHeader h ; HttpHeader.values()) {
            if(h == HttpHeader.Null)
                continue;
            string headerName = h.asString().toLower();
            // tracef("headerName:%s, ordinal=%d", headerName, h.ordinal());

            StaticEntry *entry = (headerName in __staticNameMap);
            if (entry !is null)
                __staticTableByHeader[h.ordinal()] = *entry;
        }

        // trace(__staticTableByHeader);
    }

    private int _maxDynamicTableSizeInBytes;
    private int _dynamicTableSizeInBytes;
    private DynamicTable _dynamicTable;
    private Map!(HttpField, Entry) _fieldMap; // = new HashMap!(HttpField, Entry)();
    private Map!(string, Entry) _nameMap; // = new HashMap!(string, Entry)();

    this(int maxDynamicTableSize) {
        _fieldMap = new HashMap!(HttpField, Entry)();
        _nameMap = new HashMap!(string, Entry)();

        _maxDynamicTableSizeInBytes = maxDynamicTableSize;
        int guesstimateEntries = 10 + maxDynamicTableSize / (32 + 10 + 10);
        _dynamicTable = new DynamicTable(guesstimateEntries);
        version(HuntDebugMode)
            tracef(format("HdrTbl[%x] created max=%d", toHash(), maxDynamicTableSize));
    }

    void resize(int newMaxDynamicTableSize) {
        version(HuntDebugMode)
            tracef(format("HdrTbl[%x] resized max=%d->%d", toHash(), _maxDynamicTableSizeInBytes, newMaxDynamicTableSize));
        _maxDynamicTableSizeInBytes = newMaxDynamicTableSize;
        _dynamicTable.evict();
    }

    Entry get(HttpField field) {
        Entry entry = _fieldMap.get(field);
        if (entry is null)
        {
            auto entryPtr = field in __staticFieldMap;
            if(entryPtr is null)
                // warningf("The field does not exist: %s, %s", field.toString(), field.toHash());
                warning("The field does not exist: ", field.toString());
            else
                entry = *entryPtr;
        }

        return entry;
    }

    Entry get(string name) {
        string lowerName = std.uni.toLower(name);

        StaticEntry *entry = lowerName in __staticNameMap;
        if (entry !is null)
            return *entry;
        // trace("name=", name);

        // if(!_nameMap.containsKey(n))
        //     return null;

        return _nameMap.get(lowerName);
    }

    Entry get(int index) {
        if (index <= STATIC_SIZE)
            return __staticTable[index];

        return _dynamicTable.get(index);
    }

    Entry get(HttpHeader header) {
        tracef("header:%s, ordinal=%d",header, header.ordinal());
        int o = header.ordinal();
        Entry e = __staticTableByHeader.get(o, null);
        if (e is null)
            return get(header.asString());
        return e;
    }

    static Entry getStatic(HttpHeader header) {
        return __staticTableByHeader[header.ordinal()];
    }

    Entry add(HttpField field) {
        Entry entry = new Entry(field);
        int size = entry.getSize();
        if (size > _maxDynamicTableSizeInBytes) {
            version(HuntDebugMode)
                tracef(format("HdrTbl[%x] !added size %d>%d", toHash(), size, _maxDynamicTableSizeInBytes));
            return null;
        }
        _dynamicTableSizeInBytes += size;
        _dynamicTable.add(entry);
        _fieldMap.put(field, entry);
        _nameMap.put(std.uni.toLower(field.getName()), entry);

        version(HuntDebugMode)
            tracef(format("HdrTbl[%x] added %s", toHash(), entry));
        _dynamicTable.evict();
        return entry;
    }

    /**
     * @return Current dynamic table size in entries
     */
    int size() {
        return _dynamicTable.size();
    }

    /**
     * @return Current Dynamic table size in Octets
     */
    int getDynamicTableSize() {
        return _dynamicTableSizeInBytes;
    }

    /**
     * @return Max Dynamic table size in Octets
     */
    int getMaxDynamicTableSize() {
        return _maxDynamicTableSizeInBytes;
    }

    int index(Entry entry) {
        if (entry._slot < 0)
            return 0;
        if (entry.isStatic())
            return entry._slot;

        return _dynamicTable.index(entry);
    }

    static int staticIndex(HttpHeader header) {
        if (header == HttpHeader.Null)
            return 0;
        // Entry entry = __staticNameMap[header.asString()];

        StaticEntry *entry = header.asString() in __staticNameMap;
        if (entry is null)
            return 0;
        return entry._slot;
    }


    override
    string toString() {
        return format("HpackContext@%x{entries=%d,size=%d,max=%d}", toHash(), _dynamicTable.size(), _dynamicTableSizeInBytes, _maxDynamicTableSizeInBytes);
    }

    private class DynamicTable {
        Entry[] _entries;
        int _size;
        int _offset;
        int _growby;

        private this(int initCapacity) {
            _entries = new Entry[initCapacity];
            _growby = initCapacity;
        }

        void add(Entry entry) {
            if (_size == _entries.length) {
                Entry[] entries = new Entry[_entries.length + _growby];
                for (int i = 0; i < _size; i++) {
                    int slot = (_offset + i) % cast(int)_entries.length;
                    entries[i] = _entries[slot];
                    entries[i]._slot = i;
                }
                _entries = entries;
                _offset = 0;
            }
            int slot = (_size++ + _offset) % cast(int)_entries.length;
            _entries[slot] = entry;
            entry._slot = slot;
        }

        int index(Entry entry) {
            return STATIC_SIZE + _size - (entry._slot - _offset + cast(int)_entries.length) % cast(int)_entries.length;
        }

        Entry get(int index) {
            int d = index - STATIC_SIZE - 1;
            if (d < 0 || d >= _size)
                return null;
            int slot = (_offset + _size - d - 1) % cast(int)_entries.length;
            return _entries[slot];
        }

        int size() {
            return _size;
        }

        private void evict() {
            while (_dynamicTableSizeInBytes > _maxDynamicTableSizeInBytes) {
                Entry entry = _entries[_offset];
                _entries[_offset] = null;
                _offset = (_offset + 1) % cast(int)_entries.length;
                _size--;
                version(HuntDebugMode)
                    tracef(format("HdrTbl[%x] evict %s", toHash(), entry));
                _dynamicTableSizeInBytes -= entry.getSize();
                entry._slot = -1;
                _fieldMap.remove(entry.getHttpField());
                string lc = std.uni.toLower(entry.getHttpField().getName());
                if (entry == _nameMap.get(lc))
                    _nameMap.remove(lc);

            }
            version(HuntDebugMode)
                tracef(format("HdrTbl[%x] entries=%d, size=%d, max=%d", toHash(), _dynamicTable.size(), 
                    _dynamicTableSizeInBytes, _maxDynamicTableSizeInBytes));
        }

    }

    static class Entry {
        HttpField _field;
        int _slot; // The index within it's array

        this() {
            _slot = -1;
            _field = null;
        }

        this(HttpField field) {
            _field = field;
        }

        int getSize() {
            string value = _field.getValue();
            return 32 + cast(int)(_field.getName().length + value.length);
        }

        HttpField getHttpField() {
            return _field;
        }

        bool isStatic() {
            return false;
        }

        byte[] getStaticHuffmanValue() {
            return null;
        }

        override string toString() {
            return format("{%s,%d,%s,%x}", isStatic() ? "S" : "D", _slot, _field, toHash());
        }
    }

    static class StaticEntry :Entry {
        private byte[] _huffmanValue;
        private byte _encodedField;

        this(int index, HttpField field) {
            super(field);
            _slot = index;
            string value = field.getValue();
            if (value != null && value.length > 0) {
                int huffmanLen = Huffman.octetsNeeded(value);
                int lenLen = NBitInteger.octectsNeeded(7, huffmanLen);
                _huffmanValue = new byte[1 + lenLen + huffmanLen];
                ByteBuffer buffer = ByteBuffer.wrap(_huffmanValue);

                // Indicate Huffman
                buffer.put(cast(byte) 0x80);
                // Add huffman length
                NBitInteger.encode(buffer, 7, huffmanLen);
                // Encode value
                Huffman.encode(buffer, value);
            } else
                _huffmanValue = null;

            _encodedField = cast(byte) (0x80 | index);
        }

        override
        bool isStatic() {
            return true;
        }

        override
        byte[] getStaticHuffmanValue() {
            return _huffmanValue;
        }

        byte getEncodedField() {
            return _encodedField;
        }
    }
}
