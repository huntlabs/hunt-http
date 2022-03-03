module hunt.http.HttpBody;

import hunt.http.HttpOutputStream;
import hunt.io.HeapByteBuffer;
import hunt.io.ByteBuffer;
import hunt.io.BufferUtils;

import hunt.Exceptions;
import hunt.logging;
import hunt.util.MimeType;
import hunt.util.MimeTypeUtils;

import std.array;
import std.conv;
import std.file;
import std.path;
import std.range;
import std.stdio;
import std.traits;

/** 
 * A body content that can be sent or received with an HTTP message.
 * 
 * See_Also:
 *  org.apache.hc.core5.http.HttpEntity
 */
abstract class HttpBody {

	string contentType();

    /**
     * Returns the number of bytes that will be written to {@code sink} in a call to {@link #writeTo},
     * or -1 if that count is unknown.
     */
	long contentLength() {
		return -1;
	}

    void append(ubyte[] data) {
        implementationMissing(false);
    }

    void append(ByteBuffer buffer) {
        ubyte[] content = cast(ubyte[])buffer.peekRemaining();
        append(content);
    }

    /** Writes the content of this request to {@code sink}. */
    void writeTo(HttpOutputStream sink);

    // getContent()
	string asString() {
        implementationMissing(false);
        return "";
    }

    const(ubyte)[] getRaw() {
        implementationMissing(false);
        return null;
    }

	override string toString() {
		return asString();
	}

    static HttpBody create(T)(T content) {
        static if(isSomeString!T) {
            return create(MimeType.TEXT_HTML_VALUE, content);
        } else static if(isBasicType!T) {
            return create(MimeType.TEXT_HTML_VALUE, content.to!string);
        } else  {
            // using defaults

            // TODO: Tasks pending completion -@zhangxueping at 2020-01-08T10:21:19+08:00
            // return struct and class as json string
            version(HUNT_HTTP_DEBUG) warningf("Using default conversion for %s", T.stringof);
            return create(MimeType.TEXT_HTML_VALUE, content.to!string);
        }
    }
    
    // static HttpBody create(T)(string contentType, T content) if(!isSomeString!T) {
    //     return create(contentType, content.to!string);
    // }

    static HttpBody create(string contentType, long contentLength) {
        HttpBody impl = new HttpBodyImpl(contentType, contentLength);
        return impl;
    }
	
    /**
     * Returns a new request body that transmits {@code content}. If {@code contentType} is non-null
     * and lacks a charset, this will use UTF-8.
     */
    static HttpBody create(string contentType, string content) {
        // Charset charset = UTF_8;
        if (contentType !is null) {
            // charset = contentType.charset();
			string charset = new MimeType(contentType).getCharset();
            if (charset.empty()) {
                // charset = UTF_8;
                contentType = contentType ~ ";charset=utf-8";
            }
        }
        ubyte[] bytes = cast(ubyte[])content; // content.getBytes(charset);
        return create(contentType, bytes);
    }

    static HttpBody create(string contentType, ByteBuffer buffer) {
        ubyte[] content = cast(ubyte[])buffer.peekRemaining();
        return create(contentType, content);
    }

    /** Returns a new request body that transmits {@code content}. */
    static HttpBody create(string type, const(ubyte)[] content) {
        // return create(contentType, content, 0, cast(int)content.length);
        HttpBody impl = new HttpBodyImpl(type, content);
        return impl;
    }

    /** Returns a new request body that transmits the content of {@code file}. */
    static HttpBody createFromFile(string type, string fileName) {
        if (fileName.empty()) throw new NullPointerException("fileName is null");
		
		string rootPath = dirName(thisExePath);
		string abslutePath = buildPath(rootPath, fileName);
		version(HUNT_HTTP_DEBUG) info("generate request body from file: ", abslutePath);
		if(!abslutePath.exists) throw new FileNotFoundException(fileName);

		DirEntry entry = DirEntry(abslutePath);
		if(entry.isDir()) throw new FileException("Can't handle a direcotry: ", abslutePath);

		long total = cast(long)entry.size();
		if(total > 10*1024*1024) {
			// throw new FileException("The file is too big to upload (< 10MB).");
			debug warning("uploading a big file: %d MB", total/1024/1024);
		}

// dfmt off
        return new class HttpBody {
            override string contentType() {
                return type;
            }

            override long contentLength() {
                return total;
            }


	        override string asString() {
                // FIXME: Needing refactor or cleanup -@zhangxueping at 2020-01-07T18:58:40+08:00
                // 
                return fileName;
            }

			override void writeTo(HttpOutputStream sink)  {
				version(HUNT_HTTP_DEBUG) infof("loading data from: %s, size: %d", abslutePath, total);
				enum MaxBufferSize = 16*1024;
				ubyte[] buffer;
				
				File f = File(abslutePath, "r");
				scope(exit) f.close();

				size_t remaining = cast(size_t)total;
				while(remaining > 0 && !f.eof()) {

					if(remaining > MaxBufferSize) 
						buffer = new ubyte[MaxBufferSize];
					else 
						buffer = new ubyte[remaining];
					ubyte[] data = f.rawRead(buffer);
                    
                    if(data.length > 0) {
					    sink.write(cast(byte[])data);
                        remaining -= cast(int)data.length;
                    }
                    version(HUNT_HTTP_DEBUG_MORE) {
                        tracef("read: %s, remaining: %d, eof: %s", 
                            data.length, remaining, f.eof());
                    }
				}
			}
        };
// dfmt on    
    }		
}


class HttpBodyImpl : HttpBody {

    private Appender!(const(ubyte)[]) _buffer;
    private string _type;
    private long _contentLength;

    this(string type, long contentLength) {
        _type = type;
        _contentLength = contentLength;
    }

    this(string type, const(ubyte)[] content) {
        _type = type;
        _contentLength = cast(long)content.length;
        append(content);
    }

    override string contentType() {
        return _type;
    }

    override long contentLength() {
        return _contentLength;
    }

    override void append(const(ubyte)[] data) {
        _buffer.put(data);
    }

    override string asString() {
        string str = cast(string)_buffer.data();
        version(HUNT_DEBUG) {
            if(_contentLength != -1 && str.length != _contentLength) {
                warningf("Mismatched content length, required: %d, actual: %d", _contentLength, str.length);
            }
        }
        return str;
    }

    override const(ubyte)[] getRaw() {
        const(ubyte)[] data = _buffer.data;
        version(HUNT_DEBUG) {
            if(_contentLength != -1 && data.length != _contentLength) {
                warningf("Mismatched content length, required: %d, actual: %d", _contentLength, data.length);
            }
        }
        return data;
    }

    override void writeTo(HttpOutputStream sink) {
        auto d = cast(byte[])_buffer.data;
        if(d.length > 0) {
            sink.write(d, 0, cast(int)d.length);
        }
    }
}