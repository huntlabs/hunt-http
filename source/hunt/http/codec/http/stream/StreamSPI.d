module hunt.http.codec.http.stream.StreamSPI;

import hunt.http.codec.http.stream.CloseState;
import hunt.http.codec.http.stream.Stream;
import hunt.http.codec.http.stream.SessionSPI;

import hunt.http.codec.http.frame.Frame;
import hunt.lang.common;
import hunt.util.functional;


/**
 * <p>The SPI interface for implementing a HTTP/2 stream.</p>
 * <p>This class :{@link Stream} by adding the methods required to
 * implement the HTTP/2 stream functionalities.</p>
 */
interface StreamSPI : Stream , Closeable { // 

    /**
     * @return whether this stream is local or remote
     */
    bool isLocal();

    SessionSPI getSession();

    /**
     * @return the {@link hunt.http.codec.http.stream.Stream.Listener} associated with this stream
     * @see #setListener(Stream.Listener)
     */
    Listener getListener();

    /**
     * @param listener the {@link hunt.http.codec.http.stream.Stream.Listener} associated with this stream
     * @see #getListener()
     */
    void setListener(Listener listener);

    /**
     * <p>Processes the given {@code frame}, belonging to this stream.</p>
     *
     * @param frame    the frame to process
     * @param callback the callback to complete when frame has been processed
     */
    void process(Frame frame, Callback callback);

    /**
     * <p>Updates the close state of this stream.</p>
     *
     * @param update whether to update the close state
     * @param event  the event that caused the close state update
     * @return whether the stream has been fully closed by this invocation
     */
    bool updateClose(bool update, CloseStateEvent event);

    /**
     * <p>Forcibly closes this stream.</p>
     */
    void close();

    /**
     * <p>Updates the stream send window by the given {@code delta}.</p>
     *
     * @param delta the delta value (positive or negative) to add to the stream send window
     * @return the previous value of the stream send window
     */
    int updateSendWindow(int delta);

    /**
     * <p>Updates the stream receive window by the given {@code delta}.</p>
     *
     * @param delta the delta value (positive or negative) to add to the stream receive window
     * @return the previous value of the stream receive window
     */
    int updateRecvWindow(int delta);

    /**
     * <p>Marks this stream as not idle so that the
     * {@link #getIdleTimeout() idle timeout} is postponed.</p>
     */
    // void notIdle();

    /**
     * @return whether the stream is closed remotely.
     * @see #isClosed()
     */
    bool isRemotelyClosed();
}
