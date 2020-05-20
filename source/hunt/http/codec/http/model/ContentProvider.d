module hunt.http.codec.http.model.ContentProvider;

import hunt.io.ByteBuffer;
import hunt.util.Common;

/**
 * <p>{@link ContentProvider} provides a source of request content.</p>
 * <p>Implementations should return an {@link Iterator} over the request content.
 * If the request content comes from a source that needs to be closed (for
 * example, an {@link java.io.InputStream}), then the iterator implementation class
 * must implement {@link Closeable} and will be closed when the request is
 * completed (either successfully or failed).</p>
 * <p>{@link ContentProvider} provides a {@link #getLength() length} of the content
 * it represents.
 * If the length is positive, it typically overrides any {@code Content-Length}
 * header set by applications; if the length is negative, it typically removes
 * any {@code Content-Length} header set by applications, resulting in chunked
 * content (i.e. {@code Transfer-Encoding: chunked}) being sent to the server.</p>
 */
interface ContentProvider : Iterable!ByteBuffer {
    /**
     * @return the content length, if known, or -1 if the content length is unknown
     */
    long getLength();

    /**
     * An extension of {@link ContentProvider} that provides a content type string
     * to be used as a {@code Content-Type} HTTP header in requests.
     */
    interface Typed : ContentProvider {
        /**
         * @return the content type string such as "application/octet-stream" or
         * "application/json;charset=UTF8", or null if no content type must be set
         */
        string getContentType();
    }
}
