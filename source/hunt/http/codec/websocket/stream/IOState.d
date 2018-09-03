module hunt.http.codec.websocket.stream;

import hunt.http.codec.websocket.model.CloseInfo;
import hunt.http.codec.websocket.model.ConnectionState;
import hunt.http.codec.websocket.model.StatusCode;
import hunt.http.utils.StringUtils;
import hunt.logging;


import java.io.EOFException;
import java.io.IOException;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicReference;

/**
 * Simple state tracker for Input / Output and {@link ConnectionState}.
 * <p>
 * Use the various known .on*() methods to trigger a state change.
 * <ul>
 * <li>{@link #onOpened()} - connection has been opened</li>
 * </ul>
 */
class IOState {
    /**
     * The source of a close handshake. (ie: who initiated it).
     */
    private enum CloseHandshakeSource {
        /**
         * No close handshake initiated (yet)
         */
        NONE,
        /**
         * Local side initiated the close handshake
         */
        LOCAL,
        /**
         * Remote side initiated the close handshake
         */
        REMOTE,
        /**
         * An abnormal close situation (disconnect, timeout, etc...)
         */
        ABNORMAL
    }

    interface ConnectionStateListener {
        void onConnectionStateChange(ConnectionState state);
    }


    private ConnectionState state;
    private final List<ConnectionStateListener> listeners = new CopyOnWriteArrayList<>();

    /**
     * Is input on websocket available (for reading frames).
     * Used to determine close handshake completion, and track half-close states
     */
    private bool inputAvailable;
    /**
     * Is output on websocket available (for writing frames).
     * Used to determine close handshake completion, and track half-closed states.
     */
    private bool outputAvailable;
    /**
     * Initiator of the close handshake.
     * Used to determine who initiated a close handshake for reply reasons.
     */
    private CloseHandshakeSource closeHandshakeSource;
    /**
     * The close info for the initiator of the close handshake.
     * It is possible in abnormal close scenarios to have a different
     * final close info that is used to notify the WS-Endpoint's onClose()
     * events with.
     */
    private CloseInfo closeInfo;
    /**
     * Atomic reference to the final close info.
     * This can only be set once, and is used for the WS-Endpoint's onClose()
     * event.
     */
    private AtomicReference<CloseInfo> finalClose = new AtomicReference<>();
    /**
     * Tracker for if the close handshake was completed successfully by
     * both sides.  False if close was sudden or abnormal.
     */
    private bool cleanClose;

    /**
     * Create a new IOState, initialized to {@link ConnectionState#CONNECTING}
     */
    this() {
        this.state = ConnectionState.CONNECTING;
        this.inputAvailable = false;
        this.outputAvailable = false;
        this.closeHandshakeSource = CloseHandshakeSource.NONE;
        this.closeInfo = null;
        this.cleanClose = false;
    }

    void addListener(ConnectionStateListener listener) {
        listeners.add(listener);
    }

    void assertInputOpen() throws IOException {
        if (!isInputAvailable()) {
            throw new IOException("Connection input is closed");
        }
    }

    void assertOutputOpen() throws IOException {
        if (!isOutputAvailable()) {
            throw new IOException("Connection output is closed");
        }
    }

    CloseInfo getCloseInfo() {
        CloseInfo ci = finalClose.get();
        if (ci !is null) {
            return ci;
        }
        return closeInfo;
    }

    ConnectionState getConnectionState() {
        return state;
    }

    bool isClosed() {
        synchronized (this) {
            return (state == ConnectionState.CLOSED);
        }
    }

    bool isInputAvailable() {
        return inputAvailable;
    }

    bool isOpen() {
        return !isClosed();
    }

    bool isOutputAvailable() {
        return outputAvailable;
    }

    private void notifyStateListeners(ConnectionState state) {
        version(HuntDebugMode)
            tracef("Notify State Listeners: %s", state);
        for (ConnectionStateListener listener : listeners) {
            version(HuntDebugMode) {
                tracef("%s.onConnectionStateChange(%s)", listener.typeof(this).stringof, state.name());
            }
            listener.onConnectionStateChange(state);
        }
    }

    /**
     * A websocket connection has been disconnected for abnormal close reasons.
     * <p>
     * This is the low level disconnect of the socket. It could be the result of a normal close operation, from an IO error, or even from a timeout.
     *
     * @param close the close information
     */
    void onAbnormalClose(CloseInfo close) {
        version(HuntDebugMode)
            tracef("onAbnormalClose(%s)", close);
        ConnectionState event = null;
        synchronized (this) {
            if (this.state == ConnectionState.CLOSED) {
                // already closed
                return;
            }

            if (this.state == ConnectionState.OPEN) {
                this.cleanClose = false;
            }

            this.state = ConnectionState.CLOSED;
            finalClose.compareAndSet(null, close);
            this.inputAvailable = false;
            this.outputAvailable = false;
            this.closeHandshakeSource = CloseHandshakeSource.ABNORMAL;
            event = this.state;
        }
        notifyStateListeners(event);
    }

    /**
     * A close handshake has been issued from the local endpoint
     *
     * @param closeInfo the close information
     */
    void onCloseLocal(CloseInfo closeInfo) {
        bool open = false;
        synchronized (this) {
            ConnectionState initialState = this.state;
            version(HuntDebugMode)
                tracef("onCloseLocal(%s) : %s", closeInfo, initialState);
            if (initialState == ConnectionState.CLOSED) {
                // already closed
                version(HuntDebugMode)
                    tracef("already closed");
                return;
            }

            if (initialState == ConnectionState.CONNECTED) {
                // fast close. a local close request from end-user onConnect/onOpen method
                version(HuntDebugMode)
                    tracef("FastClose in CONNECTED detected");
                open = true;
            }
        }

        if (open)
            openAndCloseLocal(closeInfo);
        else
            closeLocal(closeInfo);
    }

    private void openAndCloseLocal(CloseInfo closeInfo) {
        // Force the state open (to allow read/write to endpoint)
        onOpened();
        version(HuntDebugMode)
            tracef("FastClose continuing with Closure");
        closeLocal(closeInfo);
    }

    private void closeLocal(CloseInfo closeInfo) {
        ConnectionState event = null;
        ConnectionState abnormalEvent = null;
        synchronized (this) {
            version(HuntDebugMode)
                tracef("onCloseLocal(), input=%s, output=%s", inputAvailable, outputAvailable);

            this.closeInfo = closeInfo;

            // Turn off further output.
            outputAvailable = false;

            if (closeHandshakeSource == CloseHandshakeSource.NONE) {
                closeHandshakeSource = CloseHandshakeSource.LOCAL;
            }

            if (!inputAvailable) {
                version(HuntDebugMode)
                    tracef("Close Handshake satisfied, disconnecting");
                cleanClose = true;
                this.state = ConnectionState.CLOSED;
                finalClose.compareAndSet(null, closeInfo);
                event = this.state;
            } else if (this.state == ConnectionState.OPEN) {
                // We are now entering CLOSING (or half-closed).
                this.state = ConnectionState.CLOSING;
                event = this.state;

                // If abnormal, we don't expect an answer.
                if (closeInfo.isAbnormal()) {
                    abnormalEvent = ConnectionState.CLOSED;
                    finalClose.compareAndSet(null, closeInfo);
                    cleanClose = false;
                    outputAvailable = false;
                    inputAvailable = false;
                    closeHandshakeSource = CloseHandshakeSource.ABNORMAL;
                }
            }
        }

        // Only notify on state change events
        if (event !is null) {
            notifyStateListeners(event);
            if (abnormalEvent !is null) {
                notifyStateListeners(abnormalEvent);
            }
        }
    }

    /**
     * A close handshake has been received from the remote endpoint
     *
     * @param closeInfo the close information
     */
    void onCloseRemote(CloseInfo closeInfo) {
        version(HuntDebugMode)
            tracef("onCloseRemote(%s)", closeInfo);
        ConnectionState event = null;
        synchronized (this) {
            if (this.state == ConnectionState.CLOSED) {
                // already closed
                return;
            }

            version(HuntDebugMode)
                tracef("onCloseRemote(), input=%s, output=%s", inputAvailable, outputAvailable);

            this.closeInfo = closeInfo;

            // turn off further input
            inputAvailable = false;

            if (closeHandshakeSource == CloseHandshakeSource.NONE) {
                closeHandshakeSource = CloseHandshakeSource.REMOTE;
            }

            if (!outputAvailable) {
                tracef("Close Handshake satisfied, disconnecting");
                cleanClose = true;
                state = ConnectionState.CLOSED;
                finalClose.compareAndSet(null, closeInfo);
                event = this.state;
            } else if (this.state == ConnectionState.OPEN) {
                // We are now entering CLOSING (or half-closed)
                this.state = ConnectionState.CLOSING;
                event = this.state;
            }
        }

        // Only notify on state change events
        if (event !is null) {
            notifyStateListeners(event);
        }
    }

    /**
     * WebSocket has successfully upgraded, but the end-user onOpen call hasn't run yet.
     * <p>
     * This is an intermediate state between the RFC's {@link ConnectionState#CONNECTING} and {@link ConnectionState#OPEN}
     */
    void onConnected() {
        ConnectionState event = null;
        synchronized (this) {
            if (this.state != ConnectionState.CONNECTING) {
                tracef("Unable to set to connected, not in CONNECTING state: %s", this.state);
                return;
            }

            this.state = ConnectionState.CONNECTED;
            inputAvailable = false; // cannot read (yet)
            outputAvailable = true; // write allowed
            event = this.state;
        }
        notifyStateListeners(event);
    }

    /**
     * A websocket connection has failed its upgrade handshake, and is now closed.
     */
    void onFailedUpgrade() {
        assert (this.state == ConnectionState.CONNECTING);
        ConnectionState event = null;
        synchronized (this) {
            this.state = ConnectionState.CLOSED;
            cleanClose = false;
            inputAvailable = false;
            outputAvailable = false;
            event = this.state;
        }
        notifyStateListeners(event);
    }

    /**
     * A websocket connection has finished its upgrade handshake, and is now open.
     */
    void onOpened() {
        version(HuntDebugMode)
            tracef("onOpened()");

        ConnectionState event = null;
        synchronized (this) {
            if (this.state == ConnectionState.OPEN) {
                // already opened
                return;
            }

            if (this.state != ConnectionState.CONNECTED) {
                tracef("Unable to open, not in CONNECTED state: %s", this.state);
                return;
            }

            this.state = ConnectionState.OPEN;
            this.inputAvailable = true;
            this.outputAvailable = true;
            event = this.state;
        }
        notifyStateListeners(event);
    }

    /**
     * The local endpoint has reached a read failure.
     * <p>
     * This could be a normal result after a proper close handshake, or even a premature close due to a connection disconnect.
     *
     * @param t the read failure
     */
    void onReadFailure(Throwable t) {
        ConnectionState event = null;
        synchronized (this) {
            if (this.state == ConnectionState.CLOSED) {
                // already closed
                return;
            }

            // Build out Close Reason
            string reason = "WebSocket Read Failure";
            if (t instanceof EOFException) {
                reason = "WebSocket Read EOF";
                Throwable cause = t.getCause();
                if ((cause !is null) && (StringUtils.hasText(cause.getMessage()))) {
                    reason = "EOF: " ~ cause.getMessage();
                }
            } else {
                if (StringUtils.hasText(t.getMessage())) {
                    reason = t.getMessage();
                }
            }

            CloseInfo close = new CloseInfo(StatusCode.ABNORMAL, reason);

            finalClose.compareAndSet(null, close);

            this.cleanClose = false;
            this.state = ConnectionState.CLOSED;
            this.closeInfo = close;
            this.inputAvailable = false;
            this.outputAvailable = false;
            this.closeHandshakeSource = CloseHandshakeSource.ABNORMAL;
            event = this.state;
        }
        notifyStateListeners(event);
    }

    /**
     * The local endpoint has reached a write failure.
     * <p>
     * A low level I/O failure, or even a hunt side EndPoint close (from idle timeout) are a few scenarios
     *
     * @param t the throwable that caused the write failure
     */
    void onWriteFailure(Throwable t) {
        ConnectionState event = null;
        synchronized (this) {
            if (this.state == ConnectionState.CLOSED) {
                // already closed
                return;
            }

            // Build out Close Reason
            string reason = "WebSocket Write Failure";
            if (t instanceof EOFException) {
                reason = "WebSocket Write EOF";
                Throwable cause = t.getCause();
                if ((cause !is null) && (StringUtils.hasText(cause.getMessage()))) {
                    reason = "EOF: " ~ cause.getMessage();
                }
            } else {
                if (StringUtils.hasText(t.getMessage())) {
                    reason = t.getMessage();
                }
            }

            CloseInfo close = new CloseInfo(StatusCode.ABNORMAL, reason);

            finalClose.compareAndSet(null, close);

            this.cleanClose = false;
            this.state = ConnectionState.CLOSED;
            this.inputAvailable = false;
            this.outputAvailable = false;
            this.closeHandshakeSource = CloseHandshakeSource.ABNORMAL;
            event = this.state;
        }
        notifyStateListeners(event);
    }

    void onDisconnected() {
        ConnectionState event = null;
        synchronized (this) {
            if (this.state == ConnectionState.CLOSED) {
                // already closed
                return;
            }

            CloseInfo close = new CloseInfo(StatusCode.ABNORMAL, "Disconnected");

            this.cleanClose = false;
            this.state = ConnectionState.CLOSED;
            this.closeInfo = close;
            this.inputAvailable = false;
            this.outputAvailable = false;
            this.closeHandshakeSource = CloseHandshakeSource.ABNORMAL;
            event = this.state;
        }
        notifyStateListeners(event);
    }

    override
    string toString() {
        StringBuilder str = new StringBuilder();
        str.append(this.typeof(this).stringof);
        str.append("@").append(Integer.toHexString(hashCode()));
        str.append("[").append(state);
        str.append(',');
        if (!inputAvailable) {
            str.append('!');
        }
        str.append("in,");
        if (!outputAvailable) {
            str.append('!');
        }
        str.append("out");
        if ((state == ConnectionState.CLOSED) || (state == ConnectionState.CLOSING)) {
            CloseInfo ci = finalClose.get();
            if (ci !is null) {
                str.append(",finalClose=").append(ci);
            } else {
                str.append(",close=").append(closeInfo);
            }
            str.append(",clean=").append(cleanClose);
            str.append(",closeSource=").append(closeHandshakeSource);
        }
        str.append(']');
        return str.toString();
    }

    bool wasAbnormalClose() {
        return closeHandshakeSource == CloseHandshakeSource.ABNORMAL;
    }

    bool wasCleanClose() {
        return cleanClose;
    }

    bool wasLocalCloseInitiated() {
        return closeHandshakeSource == CloseHandshakeSource.LOCAL;
    }

    bool wasRemoteCloseInitiated() {
        return closeHandshakeSource == CloseHandshakeSource.REMOTE;
    }

}
