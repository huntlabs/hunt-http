module hunt.http.client.MultipartBody;

import hunt.http.client.RequestBody;
import hunt.http.codec.http.stream.HttpOutputStream;

import hunt.http.HttpHeader;
import hunt.http.HttpField;
import hunt.http.HttpFields;

import hunt.collection.ArrayList;
import hunt.collection.ByteBuffer;
import hunt.collection.BufferUtils;
import hunt.collection.List;
import hunt.Exceptions;
import hunt.logging.ConsoleLogger;
import hunt.text.StringBuilder;

import hunt.util.MimeType;

import std.array;
import std.conv;
import std.string;
import std.uuid;

alias ByteString = string;
alias MediaType = string;


/** An <a href="http://www.ietf.org/rfc/rfc2387.txt">RFC 2387</a>-compliant request body. */
final class MultipartBody : RequestBody {
    /**
     * The "mixed" subtype of "multipart" is intended for use when the body parts are independent and
     * need to be bundled in a particular order. Any "multipart" subtypes that an implementation does
     * not recognize must be treated as being of subtype "mixed".
     */
    enum MediaType MIXED = MimeType.MULTIPART_MIXED_VALUE;

    /**
     * The "multipart/alternative" type is syntactically identical to "multipart/mixed", but the
     * semantics are different. In particular, each of the body parts is an "alternative" version of
     * the same information.
     */
    enum MediaType ALTERNATIVE = MimeType.MULTIPART_ALTERNATIVE_VALUE;

    /**
     * This type is syntactically identical to "multipart/mixed", but the semantics are different. In
     * particular, in a digest, the default {@code Content-Type} value for a body part is changed from
     * "text/plain" to "message/rfc822".
     */
    enum MediaType DIGEST = MimeType.MULTIPART_DIGEST_VALUE;

    /**
     * This type is syntactically identical to "multipart/mixed", but the semantics are different. In
     * particular, in a parallel entity, the order of body parts is not significant.
     */
    enum MediaType PARALLEL = MimeType.MULTIPART_PARALLEL_VALUE;

    /**
     * The media-type multipart/form-data follows the rules of all multipart MIME data streams as
     * outlined in RFC 2046. In forms, there are a series of fields to be supplied by the user who
     * fills out the form. Each field has a name. Within a given form, the names are unique.
     */
    enum MediaType FORM = MimeType.MULTIPART_FORM_VALUE;

    private enum byte[] COLONSPACE = [':', ' '];
    private enum byte[] CRLF = ['\r', '\n'];
    private enum byte[] DASHDASH = ['-', '-'];

    private ByteString _boundary;
    private MediaType _originalType;
    private MediaType _contentType;
    private List!Part _parts;
    // private long _contentLength = -1L;

    this(ByteString boundary, MediaType type, List!Part parts) {
        this._boundary = boundary;
        this._originalType = type;
        this._contentType = type ~ "; boundary=" ~ boundary;
        this._parts = parts;
    }

    MediaType type() {
        return _originalType;
    }

    string boundary() {
        return _boundary;
    }

    /** The number of parts in this multipart body. */
    int size() {
        return _parts.size();
    }

    List!Part parts() {
        return _parts;
    }

    Part part(int index) {
        return _parts.get(index);
    }

    /** A combination of {@link #type()} and {@link #boundary()}. */
    override MediaType contentType() {
        return _contentType;
    }

    override long contentLength() {
        // long result = _contentLength;
        // if (result != -1L) return result;
        // return _contentLength = writeOrCountBytes(true);
        return -1;
    }

    /**
     * Either writes this request to {@code sink} or measures its content length. We have one method
     * do double-duty to make sure the counting and content are consistent, particularly when it comes
     * to awkward operations like measuring the encoded length of header strings, or the
     * length-in-digits of an encoded integer.
     */
    override void writeTo(HttpOutputStream sink) {
        long byteCount = 0L;
        Appender!(byte[]) buffer;
        
        foreach (Part part; _parts) {
            HttpFields headers = part._headers;

            buffer.put(DASHDASH);
            buffer.put(cast(byte[])_boundary);
            buffer.put(CRLF);

            foreach (HttpField field; headers) {
                buffer.put(cast(byte[])field.getName());
                buffer.put(COLONSPACE);
                buffer.put(cast(byte[])field.getValue());
                buffer.put(CRLF);
            }

            RequestBody requestBody = part._body;
            MediaType contentType = requestBody.contentType();
            long contentLength = requestBody.contentLength();

            if (contentType !is null) {
                buffer.put(cast(byte[])"Content-Type: ");
                buffer.put(cast(byte[])contentType);
                buffer.put(CRLF);
            }

            if (contentLength != -1) {
                buffer.put(cast(byte[])"Content-Length: ");
                buffer.put(cast(byte[])(contentLength.to!string()));
                buffer.put(CRLF);
            } else {
                version(HUNT_DEBUG) warning("We can't measure the body's size without the sizes of its components.");
            }

            buffer.put(CRLF);
            sink.write(buffer.data());
            requestBody.writeTo(sink);
            
            buffer = Appender!(byte[])(); // reset the buffer
            buffer.put(CRLF);
        }

        buffer.put(DASHDASH);
        buffer.put(cast(byte[])_boundary);
        buffer.put(DASHDASH);
        buffer.put(CRLF);
        buffer.put(CRLF);
        // buffer.put(cast(byte[])"0");
        // buffer.put(CRLF);
        // buffer.put(CRLF);
        sink.write(buffer.data());
    }

    /**
     * Appends a quoted-string to a StringBuilder.
     *
     * <p>RFC 2388 is rather vague about how one should escape special characters in form-data
     * parameters, and as it turns out Firefox and Chrome actually do rather different things, and
     * both say in their comments that they're not really sure what the right approach is. We go with
     * Chrome's behavior (which also experimentally seems to match what IE does), but if you actually
     * want to have a good chance of things working, please avoid double-quotes, newlines, percent
     * signs, and the like in your field names.
     */
    static void appendQuotedString(StringBuilder target, string key) {
        target.append('"');
        for (int i = 0; i < cast(int)key.length; i++) {
            char ch = key[i];
            switch (ch) {
                case '\n':
                    target.append("%0A");
                    break;
                case '\r':
                    target.append("%0D");
                    break;
                case '"':
                    target.append("%22");
                    break;
                default:
                    target.append(ch);
                    break;
            }
        }
        target.append('"');
    }

    static final class Part {

        private HttpFields _headers;
        private RequestBody _body;

        private this(HttpFields headers, RequestBody requestBody) {
            this._headers = headers;
            this._body = requestBody;
        }

        HttpFields headers() {
            return _headers;
        }

        RequestBody requestBody() {
            return _body;
        }

        static Part create(RequestBody requestBody) {
            return create(cast(HttpFields)null, requestBody);
        }

        static Part create(HttpFields headers, RequestBody requestBody) {
            if (requestBody is null) {
                throw new NullPointerException("body is null");
            }
            if (headers !is null && headers.getField("Content-Type") !is null) {
                throw new IllegalArgumentException("Unexpected header: Content-Type");
            }
            if (headers !is null && headers.getField("Content-Length") !is null) {
                throw new IllegalArgumentException("Unexpected header: Content-Length");
            }
            return new Part(headers, requestBody);
        }

        static Part createFormData(string name, string value) {
            return createFormData(name, cast(string)null, RequestBody.create(cast(string)null, value));
        }

        static Part createFormData(string name, string value, string contentType) {
            return createFormData(name, cast(string)null, RequestBody.create(contentType, value));
        }

        static Part createFormData(string name, string filename, RequestBody requestBody) {
            if (name is null) {
                throw new NullPointerException("name is null");
            }
            StringBuilder disposition = new StringBuilder("form-data; name=");
            appendQuotedString(disposition, name);

            if (filename !is null) {
                disposition.append("; filename=");
                appendQuotedString(disposition, filename);
            }

            HttpFields headers = new HttpFields();
            headers.add(HttpHeader.CONTENT_DISPOSITION, disposition.toString());

            return create(headers, requestBody);
        }        
    }

    static final class Builder {
        private ByteString _boundary;
        private MediaType type = MIXED;
        private List!Part parts;

        this() {
            this(randomUUID().toString());
            parts = new ArrayList!Part();
        }

        this(string boundary) {
            this._boundary = boundary;
            parts = new ArrayList!Part();
        }

        /**
         * Set the MIME type. Expected values for {@code type} are {@link #MIXED} (the default), {@link
         * #ALTERNATIVE}, {@link #DIGEST}, {@link #PARALLEL} and {@link #FORM}.
         */
        Builder setType(MediaType type) {
            if (type is null) {
                throw new NullPointerException("type is null");
            }

            if(!type.startsWith("multipart/")) {
                throw new IllegalArgumentException("multipart != " ~ type);
            }
            this.type = type;
            return this;
        }

        /** Add a part to the body. */
        Builder addPart(RequestBody requestBody) {
            return addPart(Part.create(requestBody));
        }

        /** Add a part to the body. */
        Builder addPart(HttpFields headers, RequestBody requestBody) {
            return addPart(Part.create(headers, requestBody));
        }

        /** Add a form data part to the body. */
        Builder addFormDataPart(string name, string value) {
            return addPart(Part.createFormData(name, value));
        }
        
        Builder addFormDataPart(string name, string value, string contentType) {
            return addPart(Part.createFormData(name, value, contentType));
        }

        /** Add a form data part to the body. */
        Builder addFormDataPart(string name, string filename, RequestBody requestBody) {
            return addPart(Part.createFormData(name, filename, requestBody));
        }

        /** Add a part to the body. */
        Builder addPart(Part part) {
            if (part is null) throw new NullPointerException("part is null");
            parts.add(part);
            return this;
        }

        /** Assemble the specified parts into a request body. */
        MultipartBody build() {
            if (parts.isEmpty()) {
                throw new IllegalStateException("Multipart body must have at least one part.");
            }
            return new MultipartBody(_boundary, type, parts);
        }
    }
}
