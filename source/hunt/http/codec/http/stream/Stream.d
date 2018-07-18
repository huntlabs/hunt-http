module hunt.http.codec.http.stream.Stream;

import hunt.http.codec.http.frame.DataFrame;
import hunt.http.codec.http.frame.HeadersFrame;
import hunt.http.codec.http.frame.PushPromiseFrame;
import hunt.http.codec.http.frame.ResetFrame;
import hunt.util.functional;

import hunt.http.codec.http.stream.Session;

import hunt.util.concurrent.Promise;


alias StreamListener = Stream.Listener;

/**
 * <p>
 * A {@link Stream} represents a bidirectional exchange of data on top of a
 * {@link Session}.
 * </p>
 * <p>
 * Differently from socket streams, where the input and output streams are
 * permanently associated with the socket (and hence with the connection that
 * the socket represents), there can be multiple HTTP/2 streams present
 * concurrent for a HTTP/2 session.
 * </p>
 * <p>
 * A {@link Stream} maps to a HTTP request/response cycle, and after the
 * request/response cycle is completed, the stream is closed and removed from
 * the session.
 * </p>
 * <p>
 * Like {@link Session}, {@link Stream} is the active part and by calling its
 * API applications can generate events on the stream; conversely,
 * {@link Stream.Listener} is the passive part, and its callbacks are invoked
 * when events happen on the stream.
 * </p>
 *
 * @see Stream.Listener
 */
interface Stream {
    /**
     * @return the stream unique id
     */
    int getId();

    /**
     * @return the session this stream is associated to
     */
    Session getSession();

    /**
     * <p>Sends the given HEADERS {@code frame} representing a HTTP response.</p>
     *
     * @param frame    the HEADERS frame to send
     * @param callback the callback that gets notified when the frame has been sent
     */
    void headers(HeadersFrame frame, Callback callback);

    /**
     * <p>Sends the given PUSH_PROMISE {@code frame}.</p>
     *
     * @param frame    the PUSH_PROMISE frame to send
     * @param promise  the promise that gets notified of the pushed stream creation
     * @param listener the listener that gets notified of stream events
     */
    void push(PushPromiseFrame frame, Promise!Stream promise, Listener listener);

    /**
     * <p>Sends the given DATA {@code frame}.</p>
     *
     * @param frame    the DATA frame to send
     * @param callback the callback that gets notified when the frame has been sent
     */
    void data(DataFrame frame, Callback callback);

    /**
     * <p>Sends the given RST_STREAM {@code frame}.</p>
     *
     * @param frame    the RST_FRAME to send
     * @param callback the callback that gets notified when the frame has been sent
     */
    void reset(ResetFrame frame, Callback callback);

    /**
     * @param key the attribute key
     * @return an arbitrary object associated with the given key to this stream
     * or null if no object can be found for the given key.
     * @see #setAttribute(string, Object)
     */
    Object getAttribute(string key);

    /**
     * @param key   the attribute key
     * @param value an arbitrary object to associate with the given key to this stream
     * @see #getAttribute(string)
     * @see #removeAttribute(string)
     */
    void setAttribute(string key, Object value);

    /**
     * @param key the attribute key
     * @return the arbitrary object associated with the given key to this stream
     * @see #setAttribute(string, Object)
     */
    Object removeAttribute(string key);

    /**
     * @return whether this stream has been reset
     */
    bool isReset();

    /**
     * @return whether this stream is closed, both locally and remotely.
     */
    bool isClosed();

    /**
     * @return the stream idle timeout
     * @see #setIdleTimeout(long)
     */
    // long getIdleTimeout();

    /**
     * @param idleTimeout the stream idle timeout
     * @see #getIdleTimeout()
     * @see Stream.Listener#onIdleTimeout(Stream, Exception)
     */
    // void setIdleTimeout(long idleTimeout);

    string toString();

    /**
     * <p>A {@link Stream.Listener} is the passive counterpart of a {@link Stream} and receives
     * events happening on a HTTP/2 stream.</p>
     *
     * @see Stream
     */
    interface Listener {
        /**
         * <p>Callback method invoked when a HEADERS frame representing the HTTP response has been received.</p>
         *
         * @param stream the stream
         * @param frame  the HEADERS frame received
         */
        void onHeaders(Stream stream, HeadersFrame frame);

        /**
         * <p>Callback method invoked when a PUSH_PROMISE frame has been received.</p>
         *
         * @param stream the stream
         * @param frame  the PUSH_PROMISE frame received
         * @return a Stream.Listener that will be notified of pushed stream events
         */
        Listener onPush(Stream stream, PushPromiseFrame frame);

        /**
         * <p>Callback method invoked when a DATA frame has been received.</p>
         *
         * @param stream   the stream
         * @param frame    the DATA frame received
         * @param callback the callback to complete when the bytes of the DATA frame have been consumed
         */
        void onData(Stream stream, DataFrame frame, Callback callback);

        void onReset(Stream stream, ResetFrame frame, Callback callback);

        // void onReset(Stream stream, ResetFrame frame, Callback callback) {
        //     try {
        //         onReset(stream, frame);
        //         callback.succeeded();
        //     } catch (Exception x) {
        //         callback.failed(x);
        //     }
        // }

        /**
         * <p>Callback method invoked when a RST_STREAM frame has been received for this stream.</p>
         *
         * @param stream the stream
         * @param frame  the RST_FRAME received
         * @see Session.Listener#onReset(Session, ResetFrame)
         */
        void onReset(Stream stream, ResetFrame frame);

        /**
         * <p>Callback method invoked when the stream exceeds its idle timeout.</p>
         *
         * @param stream the stream
         * @param x      the timeout failure
         * @see #getIdleTimeout()
         * @deprecated use {@link #onIdleTimeout(Stream, Exception)} instead
         */
        // deprecated("")
        // default void onTimeout(Stream stream, Exception x) {
        // }

        /**
         * <p>Callback method invoked when the stream exceeds its idle timeout.</p>
         *
         * @param stream the stream
         * @param x      the timeout failure
         * @return true to reset the stream, false to ignore the idle timeout
         * @see #getIdleTimeout()
         */
        bool onIdleTimeout(Stream stream, Exception x);
        
        string toString();


        /**
         * <p>Empty implementation of {@link Listener}</p>
         */
        static class Adapter : Listener {
            
            void onHeaders(Stream stream, HeadersFrame frame) {
            }

            
            Listener onPush(Stream stream, PushPromiseFrame frame) {
                return null;
            }

            
            void onData(Stream stream, DataFrame frame, Callback callback) {
                callback.succeeded();
            }

            void onReset(Stream stream, ResetFrame frame, Callback callback) {
                try {
                    onReset(stream, frame);
                    callback.succeeded();
                } catch (Exception x) {
                    callback.failed(x);
                }
            }

            void onReset(Stream stream, ResetFrame frame) {
            }

            void onTimeout(Stream stream, Exception x) {
            }

            
            bool onIdleTimeout(Stream stream, Exception x) {
                return true;
            }


			override string toString()
			{
				return super.toString();
			}
        }
    }
}
