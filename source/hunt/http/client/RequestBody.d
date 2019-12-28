module hunt.http.client.RequestBody;

import hunt.http.codec.http.stream.HttpOutputStream;

import hunt.collection.HeapByteBuffer;
import hunt.collection.ByteBuffer;
import hunt.collection.BufferUtils;

import hunt.Exceptions;
import hunt.util.MimeType;

import std.range;

/**
*/
class RequestBody {
	protected ByteBuffer _content;
	protected string _contentType;
	protected long _contentLength;

	protected this() {
		this._contentType = MimeType.TEXT_PLAIN_VALUE;
		this._contentLength = 0;
		_content = BufferUtils.allocate(1024);
	}

	this(string contentType, string content) {
		ByteBuffer buffer = new HeapByteBuffer(cast(byte[])content, 0, cast(int)content.length);
		this(contentType, cast(long)content.length, buffer);
	}

	this(string contentType, long contentLength, ByteBuffer content) {

		if (content is null) throw new NullPointerException("content == null");
		this._content = content;
		this._contentLength = contentLength;
		this._contentType = contentType;
	}

	string contentType() {
		return _contentType;
	}

	long contentLength() {
		return _contentLength;
	}

    /** Writes the content of this request to {@code sink}. */
	void writeTo(HttpOutputStream sink) {
		sink.write(_content);
	}
    // void writeTo(HttpOutputStream sink);

	// ByteBuffer content() {
	// 	return _content;
	// }



	
    /**
     * Returns a new request body that transmits {@code content}. If {@code contentType} is non-null
     * and lacks a charset, this will use UTF-8.
     */
    static RequestBody create(string contentType, string content) {
        // Charset charset = UTF_8;
        if (contentType !is null) {
            // charset = contentType.charset();
			string charset = new MimeType(contentType).getCharset();
            if (charset.empty()) {
                // charset = UTF_8;
                contentType = contentType ~ "; charset=utf-8";
            }
        }
        byte[] bytes = cast(byte[])content; // content.getBytes(charset);
        return create(contentType, bytes);
    }

	
    /** Returns a new request body that transmits {@code content}. */
    static RequestBody create(string contentType, byte[] content) {
        return create(contentType, content, 0, cast(int)content.length);
    }

    /** Returns a new request body that transmits {@code content}. */
    static RequestBody create(string type, byte[] content,
            int offset, int byteCount) {

        if (content.empty()) throw new NullPointerException("content is null");
        // Util.checkOffsetAndCount(content.length, offset, byteCount);
		assert(offset + byteCount <= content.length);

        return new class RequestBody {

            override string contentType() {
                return type;
            }

            override long contentLength() {
                return byteCount;
            }

            override void writeTo(HttpOutputStream sink) {
                sink.write(content, offset, byteCount);
            }
        };
    }

	// string asString() {
	// 	if(_content is null)
	// 		return "";

	// 	return BufferUtils.toString(_content);
	// }	
}