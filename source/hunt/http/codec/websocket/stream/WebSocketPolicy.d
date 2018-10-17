module hunt.http.codec.websocket.stream.WebSocketPolicy;

import hunt.http.codec.websocket.exception;
import hunt.http.codec.websocket.model.StatusCode;
import hunt.http.codec.websocket.model.common;

import hunt.lang.exception;
import hunt.string;

import std.conv;
import std.format;

/**
 * Settings for WebSocket operations.
 */
class WebSocketPolicy {
    private enum int KB = 1024;

    static WebSocketPolicy newClientPolicy() {
        return new WebSocketPolicy(WebSocketBehavior.CLIENT);
    }

    static WebSocketPolicy newServerPolicy() {
        return new WebSocketPolicy(WebSocketBehavior.SERVER);
    }

    /**
     * The maximum size of a text message during parsing/generating.
     * <p>
     * Text messages over this maximum will result in a close code 1009 {@link StatusCode#MESSAGE_TOO_LARGE}
     * <p>
     * Default: 65536 (64 K)
     */
    private int maxTextMessageSize = 64 * KB;

    /**
     * The maximum size of a text message buffer.
     * <p>
     * Used ONLY for stream based message writing.
     * <p>
     * Default: 32768 (32 K)
     */
    private int maxTextMessageBufferSize = 32 * KB;

    /**
     * The maximum size of a binary message during parsing/generating.
     * <p>
     * Binary messages over this maximum will result in a close code 1009 {@link StatusCode#MESSAGE_TOO_LARGE}
     * <p>
     * Default: 65536 (64 K)
     */
    private int maxBinaryMessageSize = 64 * KB;

    /**
     * The maximum size of a binary message buffer
     * <p>
     * Used ONLY for for stream based message writing
     * <p>
     * Default: 32768 (32 K)
     */
    private int maxBinaryMessageBufferSize = 32 * KB;

    /**
     * The timeout in ms (milliseconds) for async write operations.
     * <p>
     * Negative values indicate a disabled timeout.
     */
    private long asyncWriteTimeout = 60000;

    /**
     * The time in ms (milliseconds) that a websocket may be idle before closing.
     * <p>
     * Default: 300000 (ms)
     */
    private long idleTimeout = 300000;

    /**
     * The size of the input (read from network layer) buffer size.
     * <p>
     * Default: 4096 (4 K)
     */
    private int inputBufferSize = 4 * KB;

    /**
     * Behavior of the websockets
     */
    private WebSocketBehavior behavior;

    this(WebSocketBehavior behavior) {
        this.behavior = behavior;
    }

    private void assertLessThan(string name, long size, string otherName, long otherSize) {
        if (size > otherSize) {
            throw new IllegalArgumentException(format("%s [%d] must be less than %s [%d]", name, size, otherName, otherSize));
        }
    }

    private void assertGreaterThan(string name, long size, long minSize) {
        if (size < minSize) {
            throw new IllegalArgumentException(format("%s [%d] must be a greater than or equal to %d", name, size, minSize));
        }
    }

    void assertValidBinaryMessageSize(int requestedSize) {
        if (maxBinaryMessageSize > 0) {
            // validate it
            if (requestedSize > maxBinaryMessageSize) {
                throw new MessageTooLargeException("Binary message size [" ~ requestedSize.to!string() ~ "] exceeds maximum size [" ~ maxBinaryMessageSize.to!string() ~ "]");
            }
        }
    }

    void assertValidTextMessageSize(int requestedSize) {
        if (maxTextMessageSize > 0) {
            // validate it
            if (requestedSize > maxTextMessageSize) {
                throw new MessageTooLargeException("Text message size [" ~ requestedSize.to!string() ~ "] exceeds maximum size [" ~ maxTextMessageSize.to!string() ~ "]");
            }
        }
    }

    WebSocketPolicy clonePolicy() {
        WebSocketPolicy clone = new WebSocketPolicy(this.behavior);
        clone.idleTimeout = this.idleTimeout;
        clone.maxTextMessageSize = this.maxTextMessageSize;
        clone.maxTextMessageBufferSize = this.maxTextMessageBufferSize;
        clone.maxBinaryMessageSize = this.maxBinaryMessageSize;
        clone.maxBinaryMessageBufferSize = this.maxBinaryMessageBufferSize;
        clone.inputBufferSize = this.inputBufferSize;
        clone.asyncWriteTimeout = this.asyncWriteTimeout;
        return clone;
    }

    /**
     * The timeout in ms (milliseconds) for async write operations.
     * <p>
     * Negative values indicate a disabled timeout.
     *
     * @return the timeout for async write operations. negative values indicate disabled timeout.
     */
    long getAsyncWriteTimeout() {
        return asyncWriteTimeout;
    }

    WebSocketBehavior getBehavior() {
        return behavior;
    }

    /**
     * The time in ms (milliseconds) that a websocket connection mad by idle before being closed automatically.
     *
     * @return the timeout in milliseconds for idle timeout.
     */
    long getIdleTimeout() {
        return idleTimeout;
    }

    /**
     * The size of the input (read from network layer) buffer size.
     * <p>
     * This is the raw read operation buffer size, before the parsing of the websocket frames.
     *
     * @return the raw network bytes read operation buffer size.
     */
    int getInputBufferSize() {
        return inputBufferSize;
    }

    /**
     * Get the maximum size of a binary message buffer (for streaming writing)
     *
     * @return the maximum size of a binary message buffer
     */
    int getMaxBinaryMessageBufferSize() {
        return maxBinaryMessageBufferSize;
    }

    /**
     * Get the maximum size of a binary message during parsing.
     * <p>
     * This is a memory conservation option, memory over this limit will not be
     * allocated by Hunt for handling binary messages.  This applies to individual frames,
     * whole message handling, and partial message handling.
     * </p>
     * <p>
     * Binary messages over this maximum will result in a close code 1009 {@link StatusCode#MESSAGE_TOO_LARGE}
     * </p>
     *
     * @return the maximum size of a binary message
     */
    int getMaxBinaryMessageSize() {
        return maxBinaryMessageSize;
    }

    /**
     * Get the maximum size of a text message buffer (for streaming writing)
     *
     * @return the maximum size of a text message buffer
     */
    int getMaxTextMessageBufferSize() {
        return maxTextMessageBufferSize;
    }

    /**
     * Get the maximum size of a text message during parsing.
     * <p>
     * This is a memory conservation option, memory over this limit will not be
     * allocated by Hunt for handling text messages.  This applies to individual frames,
     * whole message handling, and partial message handling.
     * </p>
     * <p>
     * Text messages over this maximum will result in a close code 1009 {@link StatusCode#MESSAGE_TOO_LARGE}
     * </p>
     *
     * @return the maximum size of a text message.
     */
    int getMaxTextMessageSize() {
        return maxTextMessageSize;
    }

    /**
     * The timeout in ms (milliseconds) for async write operations.
     * <p>
     * Negative values indicate a disabled timeout.
     *
     * @param ms the timeout in milliseconds
     */
    void setAsyncWriteTimeout(long ms) {
        assertLessThan("AsyncWriteTimeout", ms, "IdleTimeout", idleTimeout);
        this.asyncWriteTimeout = ms;
    }

    /**
     * The time in ms (milliseconds) that a websocket may be idle before closing.
     *
     * @param ms the timeout in milliseconds
     */
    void setIdleTimeout(long ms) {
        assertGreaterThan("IdleTimeout", ms, 0);
        this.idleTimeout = ms;
    }

    /**
     * The size of the input (read from network layer) buffer size.
     *
     * @param size the size in bytes
     */
    void setInputBufferSize(int size) {
        assertGreaterThan("InputBufferSize", size, 1);
        this.inputBufferSize = size;
    }

    /**
     * The maximum size of a binary message buffer.
     * <p>
     * Used ONLY for stream based binary message writing.
     *
     * @param size the maximum size of the binary message buffer
     */
    void setMaxBinaryMessageBufferSize(int size) {
        assertGreaterThan("MaxBinaryMessageBufferSize", size, 1);

        this.maxBinaryMessageBufferSize = size;
    }

    /**
     * The maximum size of a binary message during parsing.
     * <p>
     * This is a memory conservation option, memory over this limit will not be
     * allocated by Hunt for handling binary messages.  This applies to individual frames,
     * whole message handling, and partial message handling.
     * </p>
     * <p>
     * Binary messages over this maximum will result in a close code 1009 {@link StatusCode#MESSAGE_TOO_LARGE}
     * </p>
     *
     * @param size the maximum allowed size of a binary message.
     */
    void setMaxBinaryMessageSize(int size) {
        assertGreaterThan("MaxBinaryMessageSize", size, -1);

        this.maxBinaryMessageSize = size;
    }

    /**
     * The maximum size of a text message buffer.
     * <p>
     * Used ONLY for stream based text message writing.
     *
     * @param size the maximum size of the text message buffer
     */
    void setMaxTextMessageBufferSize(int size) {
        assertGreaterThan("MaxTextMessageBufferSize", size, 1);

        this.maxTextMessageBufferSize = size;
    }

    /**
     * The maximum size of a text message during parsing.
     * <p>
     * This is a memory conservation option, memory over this limit will not be
     * allocated by Hunt for handling text messages.  This applies to individual frames,
     * whole message handling, and partial message handling.
     * </p>
     * <p>
     * Text messages over this maximum will result in a close code 1009 {@link StatusCode#MESSAGE_TOO_LARGE}
     * </p>
     *
     * @param size the maximum allowed size of a text message.
     */
    void setMaxTextMessageSize(int size) {
        assertGreaterThan("MaxTextMessageSize", size, -1);

        this.maxTextMessageSize = size;
    }

    override
    string toString() {
        StringBuilder builder = new StringBuilder();
        builder.append("WebSocketPolicy@").append(toHash().to!string(16));
        builder.append("[behavior=").append(behavior);
        builder.append(",maxTextMessageSize=").append(maxTextMessageSize);
        builder.append(",maxTextMessageBufferSize=").append(maxTextMessageBufferSize);
        builder.append(",maxBinaryMessageSize=").append(maxBinaryMessageSize);
        builder.append(",maxBinaryMessageBufferSize=").append(maxBinaryMessageBufferSize);
        builder.append(",asyncWriteTimeout=").append(cast(int)asyncWriteTimeout);
        builder.append(",idleTimeout=").append(cast(int)idleTimeout);
        builder.append(",inputBufferSize=").append(inputBufferSize);
        builder.append("]");
        return builder.toString();
    }
}
