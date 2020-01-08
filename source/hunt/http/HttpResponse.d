module hunt.http.HttpResponse;

import hunt.http.HttpField;
import hunt.http.HttpFields;
import hunt.http.HttpHeader;
import hunt.http.HttpMetaData;
import hunt.http.HttpScheme;
import hunt.http.HttpVersion;

import hunt.collection;
import hunt.Functions;
import hunt.Exceptions;
import hunt.logging.ConsoleLogger;
import hunt.net.util.HttpURI;
import hunt.text.Common;
import hunt.text.StringBuilder;
import hunt.util.Common;
import hunt.util.MimeType;

import std.ascii;
import std.conv;
import std.format;
import std.range;
import std.traits;

/**
 * 
 */
class HttpResponse : HttpMetaData {
    protected int _status;
    protected string _reason;

    this() {
        this(HttpVersion.Null, 0, new HttpFields());
    }

    this(HttpVersion ver, int status, HttpFields fields) {
        this(ver, status, fields, long.min);
    }

    this(HttpVersion ver, int status, HttpFields fields, long contentLength) {
        super(ver, fields, contentLength);
        _status = status;
    }

    this(HttpVersion ver, int status, string reason, HttpFields fields, long contentLength) {
        super(ver, fields, contentLength);
        _reason = reason;
        _status = status;
    }

    override bool isResponse() {
        return true;
    }

    /**
     * @return the HTTP status
     */
    int getStatus() {
        return _status;
    }

    /**
    * @return the HTTP reason
    */
    string getReason() {
        return _reason;
    }

    /**
    * @param status the HTTP status to set
    */
    void setStatus(int status) {
        _status = status;
    }

    /**
    * @param reason the HTTP reason to set
    */
    void setReason(string reason) {
        _reason = reason;
    }

    // void setHeader(T = string)(HttpHeader header, T value) {
    //     getFields().put(header, value);
    // }

    // void setHeader(T = string)(string header, T value) {
    //     getFields().put(header, value);
    // }

    deprecated("Using header instead.")
    alias setHeader = header;
    HttpResponse header(T)(string header, T value) {
        getFields().put(header, value);
        return this;
    }

    HttpResponse header(T)(HttpHeader header, T value) {
        getFields().put(header, value);
        return this;
    }    

    HttpResponse headers(T = string)(T[string] value) {
        foreach (string k, T v; value) {
            getFields().add(k, v);
        }
        return this;
    }

    alias code = getStatus;
    alias message = getReason;
    
    /**
    * Returns true if the code is in [200..300), which means the request was successfully received,
    * understood, and accepted.
    */
    bool isSuccessful() {
        return _status >= 200 && _status < 300;
    }


	// override bool haveBody() {
	// 	return _body !is null;
	// }

    override string toString() {
        HttpFields fields = getFields();
        return format("%s{s=%d,h=%d,cl=%d}", getHttpVersion(), getStatus(), 
            fields is null ? -1 : fields.size(), getContentLength());
    }
}


/**
 * 
 */
// class ResponseBody {
// 	private ByteBuffer _content;
// 	private string _contentType;
// 	private long _contentLength;

//     private this() {

//     }

// 	this(string contentType, long contentLength, ByteBuffer content) {

// 		if (content is null) throw new NullPointerException("content == null");
// 		this._content = content;
// 		this._contentLength = contentLength;
// 		this._contentType = contentType;
// 	}

// 	string contentType() {
// 		return _contentType;
// 	}

// 	long contentLength() {
// 		return _contentLength;
// 	}

// 	string asString() {
// 		if(_content is null)
// 			return "";
// 		return BufferUtils.toString(_content);
// 	}

// 	override string toString() {
// 		return asString();
// 	}

//     static Builder builder() {
//         return new Builder();
//     }

//     /**
//      * 
//      */
//     static final class Builder {

//         ResponseBody _body;
//         // private ByteBuffer _content;
//         // private string _contentType;
//         // private long _contentLength;

//         this() {
//             // _body = new ResponseBody();
//         }

//         Builder content(T)(T value) {
//             assert(_body is null, "The content can't be overwritten!");

//             static if(isSomeString!T) {
//                 _body = new ResponseBody(MimeType.TEXT_PLAIN_VALUE, 
//                         cast(long)value.length, BufferUtils.wrap(cast(byte[])value));
//             } else {

//             }

//             return this;
//         }

//         ResponseBody build() {
//             return _body;
//         }
//     }
// }
