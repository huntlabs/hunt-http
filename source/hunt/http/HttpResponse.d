module hunt.http.HttpResponse;

import hunt.http.codec.http.model.HostPortHttpField;

import hunt.http.HttpMetaData;

import hunt.http.HttpHeader;
import hunt.http.HttpField;
import hunt.http.HttpFields;
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

import std.ascii;
import std.format;
import std.range;

/**
 * 
 */
class HttpResponse : HttpMetaData {
    protected int _status;
    protected string _reason;

    this() {
        this(HttpVersion.Null, 0, null);
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

    alias code = getStatus;
    alias message = getReason;
    
    /**
    * Returns true if the code is in [200..300), which means the request was successfully received,
    * understood, and accepted.
    */
    bool isSuccessful() {
        return _status >= 200 && _status < 300;
    }

    override string toString() {
        HttpFields fields = getFields();
        return format("%s{s=%d,h=%d,cl=%d}", getHttpVersion(), getStatus(), 
            fields is null ? -1 : fields.size(), getContentLength());
    }
}