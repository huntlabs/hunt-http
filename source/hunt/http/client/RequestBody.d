module hunt.http.client.RequestBody;

import hunt.collection.HeapByteBuffer;
import hunt.collection.ByteBuffer;
import hunt.collection.BufferUtils;

import hunt.Exceptions;
import hunt.util.MimeType;

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

	size_t contentLength() {
		return _contentLength;
	}

	ByteBuffer content() {
		return _content;
	}

	// string asString() {
	// 	if(_content is null)
	// 		return "";

	// 	return BufferUtils.toString(_content);
	// }	
}