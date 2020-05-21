module hunt.http.codec.websocket.stream.IOState;

import hunt.http.codec.websocket.model.CloseInfo;
import hunt.http.WebSocketStatusCode;
import hunt.http.WebSocketConnection;

import hunt.collection;
import hunt.logging;
import hunt.Exceptions;
import hunt.text.Common;
import hunt.util.StringBuilder;

import std.array;
import std.conv;


alias ConnectionStateListener = void delegate(WebSocketConnectionState state);

/**
 * Simple state tracker for Input / Output and {@link WebSocketConnectionState}.
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

    private WebSocketConnectionState state;
    private List!(ConnectionStateListener) listeners;

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
    private CloseInfo finalClose;
    /**
     * Tracker for if the close handshake was completed successfully by
     * both sides.  False if close was sudden or abnormal.
     */
    private bool cleanClose;

    /**
     * Create a new IOState, initialized to {@link WebSocketConnectionState#CONNECTING}
     */
    this() {
        // finalClose = new AtomicReference!(CloseInfo)();
        // listeners = new CopyOnWriteArrayList!(ConnectionStateListener)();
        listeners = new ArrayList!(ConnectionStateListener)();

        this.state = WebSocketConnectionState.CONNECTING;
        this.inputAvailable = false;
        this.outputAvailable = false;
        this.closeHandshakeSource = CloseHandshakeSource.NONE;
        this.closeInfo = null;
        this.cleanClose = false;
    }

    void addListener(ConnectionStateListener listener) {
        assert(listener !is null);
        listeners.add(listener);
    }

    void assertInputOpen() {
        if (!isInputAvailable()) {
            throw new IOException("Connection input is closed");
        }
    }

    void assertOutputOpen() {
        if (!isOutputAvailable()) {
            throw new IOException("Connection output is closed");
        }
    }

    CloseInfo getCloseInfo() {
        CloseInfo ci = finalClose;
        if (ci !is null) {
            return ci;
        }
        return closeInfo;
    }

    WebSocketConnectionState getConnectionState() {
        return state;
    }

    bool isClosed() {
        synchronized (this) {
            return (state == WebSocketConnectionState.CLOSED);
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

    private void notifyStateListeners(WebSocketConnectionState state) {
        version(HUNT_HTTP_DEBUG)
            tracef("Notify State Listeners(%d): %s", listeners.size(), state);
        foreach (ConnectionStateListener listener ; listeners) {
            listener(state);
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
        version(HUNT_HTTP_DEBUG)
            tracef("onAbnormalClose(%s)", close);
        WebSocketConnectionState event = WebSocketConnectionState.Unknown;
        synchronized (this) {
            if (this.state == WebSocketConnectionState.CLOSED) {
                // already closed
                return;
            }

            if (this.state == WebSocketConnectionState.OPEN) {
                this.cleanClose = false;
            }

            this.state = WebSocketConnectionState.CLOSED;
            finalClose = close;
            // finalClose.compareAndSet(null, close);
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
            WebSocketConnectionState initialState = this.state;
            version(HUNT_HTTP_DEBUG)
                tracef("onCloseLocal(%s) : %s", closeInfo, initialState);
            if (initialState == WebSocketConnectionState.CLOSED) {
                // already closed
                version(HUNT_HTTP_DEBUG)
                    tracef("already closed");
                return;
            }

            if (initialState == WebSocketConnectionState.CONNECTED) {
                // fast close. a local close request from end-user onConnect/onOpen method
                version(HUNT_HTTP_DEBUG)
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
        version(HUNT_HTTP_DEBUG)
            tracef("FastClose continuing with Closure");
        closeLocal(closeInfo);
    }

    private void closeLocal(CloseInfo closeInfo) {
        WebSocketConnectionState event = WebSocketConnectionState.Unknown;
        WebSocketConnectionState abnormalEvent = WebSocketConnectionState.Unknown;
        synchronized (this) {
            version(HUNT_HTTP_DEBUG)
                tracef("onCloseLocal(), input=%s, output=%s", inputAvailable, outputAvailable);

            this.closeInfo = closeInfo;

            // Turn off further output.
            outputAvailable = false;

            if (closeHandshakeSource == CloseHandshakeSource.NONE) {
                closeHandshakeSource = CloseHandshakeSource.LOCAL;
            }

            if (!inputAvailable) {
                version(HUNT_HTTP_DEBUG)
                    tracef("Close Handshake satisfied, disconnecting");
                cleanClose = true;
                this.state = WebSocketConnectionState.CLOSED;
                // finalClose.compareAndSet(null, closeInfo);
                finalClose = closeInfo;
                event = this.state;
            } else if (this.state == WebSocketConnectionState.OPEN) {
                // We are now entering CLOSING (or half-closed).
                this.state = WebSocketConnectionState.CLOSING;
                event = this.state;

                // If abnormal, we don't expect an answer.
                if (closeInfo.isAbnormal()) {
                    abnormalEvent = WebSocketConnectionState.CLOSED;
                    // finalClose.compareAndSet(null, closeInfo);
                    finalClose = closeInfo;
                    cleanClose = false;
                    outputAvailable = false;
                    inputAvailable = false;
                    closeHandshakeSource = CloseHandshakeSource.ABNORMAL;
                }
            }
        }

        // Only notify on state change events
        if (event != WebSocketConnectionState.Unknown) {
            notifyStateListeners(event);
            if (abnormalEvent != WebSocketConnectionState.Unknown) {
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
        version(HUNT_HTTP_DEBUG_MORE)
            tracef("onCloseRemote(%s)", closeInfo);
        WebSocketConnectionState event = WebSocketConnectionState.Unknown;
        synchronized (this) {
            if (this.state == WebSocketConnectionState.CLOSED) {
                // already closed
                return;
            }

            version(HUNT_HTTP_DEBUG_MORE)
                tracef("onCloseRemote(), input=%s, output=%s", inputAvailable, outputAvailable);

            this.closeInfo = closeInfo;

            // turn off further input
            inputAvailable = false;

            if (closeHandshakeSource == CloseHandshakeSource.NONE) {
                closeHandshakeSource = CloseHandshakeSource.REMOTE;
            }

            if (!outputAvailable) {
                version(HUNT_HTTP_DEBUG) tracef("Close Handshake satisfied, disconnecting");
                cleanClose = true;
                state = WebSocketConnectionState.CLOSED;
                finalClose = closeInfo;
                // finalClose.compareAndSet(null, closeInfo);
                event = this.state;
            } else if (this.state == WebSocketConnectionState.OPEN) {
                // We are now entering CLOSING (or half-closed)
                this.state = WebSocketConnectionState.CLOSING;
                event = this.state;
            }
        }

        // Only notify on state change events
        if (event != WebSocketConnectionState.Unknown) {
            notifyStateListeners(event);
        }
    }

    /**
     * WebSocket has successfully upgraded, but the end-user onOpen call hasn't run yet.
     * <p>
     * This is an intermediate state between the RFC's {@link WebSocketConnectionState#CONNECTING} and {@link WebSocketConnectionState#OPEN}
     */
    void onConnected() {
        WebSocketConnectionState event = WebSocketConnectionState.Unknown;
        synchronized (this) {
            if (this.state != WebSocketConnectionState.CONNECTING) {
                tracef("Unable to set to connected, not in CONNECTING state: %s", this.state);
                return;
            }

            this.state = WebSocketConnectionState.CONNECTED;
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
        assert (this.state == WebSocketConnectionState.CONNECTING);
        WebSocketConnectionState event = WebSocketConnectionState.Unknown;
        synchronized (this) {
            this.state = WebSocketConnectionState.CLOSED;
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
        version(HUNT_HTTP_DEBUG) tracef("state: %s", this.state);

        WebSocketConnectionState event = WebSocketConnectionState.Unknown;
        synchronized (this) {
            if (this.state == WebSocketConnectionState.OPEN || 
                this.state == WebSocketConnectionState.CONNECTING) {
                // already opened
                return;
            }

            if (this.state != WebSocketConnectionState.CONNECTED) {
                warningf("Unable to open, not in CONNECTED state: %s", this.state);
                return;
            }

            this.state = WebSocketConnectionState.OPEN;
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
        WebSocketConnectionState event = WebSocketConnectionState.Unknown;
        synchronized (this) {
            if (this.state == WebSocketConnectionState.CLOSED) {
                // already closed
                return;
            }

            // Build out Close Reason
            string reason = "WebSocket Read Failure";
            EOFException ee = cast(EOFException)t;
            if (ee !is null) {
                reason = "WebSocket Read EOF";
                Throwable cause = t.next();
                if ((cause !is null) && (!cause.message().empty())) {
                    reason = "EOF: " ~ cast(string)cause.message();
                }
            } else {
                if (!t.message().empty()) {
                    reason = cast(string)t.message();
                }
            }

            CloseInfo close = new CloseInfo(StatusCode.ABNORMAL, reason);
            finalClose = close;
            // finalClose.compareAndSet(null, close);

            this.cleanClose = false;
            this.state = WebSocketConnectionState.CLOSED;
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
        WebSocketConnectionState event = WebSocketConnectionState.Unknown;
        synchronized (this) {
            if (this.state == WebSocketConnectionState.CLOSED) {
                // already closed
                return;
            }

            // Build out Close Reason
            string reason = "WebSocket Write Failure";
            EOFException ee = cast(EOFException)t;
            if (ee !is null) {
                reason = "WebSocket Write EOF";
                Throwable cause = t.next();

                if ((cause !is null) && (!cause.message().empty())) {
                    reason = "EOF: " ~ cast(string)cause.message();
                }
            } else {
                if (!t.message().empty()) {
                    reason = cast(string)t.message();
                }
            }

            CloseInfo close = new CloseInfo(StatusCode.ABNORMAL, reason);
            finalClose = close;
            // finalClose.compareAndSet(null, close);

            this.cleanClose = false;
            this.state = WebSocketConnectionState.CLOSED;
            this.inputAvailable = false;
            this.outputAvailable = false;
            this.closeHandshakeSource = CloseHandshakeSource.ABNORMAL;
            event = this.state;
        }
        notifyStateListeners(event);
    }

    void onDisconnected() {
        WebSocketConnectionState event = WebSocketConnectionState.Unknown;
        synchronized (this) {
            if (this.state == WebSocketConnectionState.CLOSED) {
                // already closed
                return;
            }

            CloseInfo close = new CloseInfo(StatusCode.ABNORMAL, "Disconnected");

            this.cleanClose = false;
            this.state = WebSocketConnectionState.CLOSED;
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
        str.append(typeid(this).name);
        str.append("@").append(to!string(toHash(), 16));
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
        if ((state == WebSocketConnectionState.CLOSED) || (state == WebSocketConnectionState.CLOSING)) {
            CloseInfo ci = finalClose;
            if (ci !is null) {
                str.append(",finalClose=").append(ci.toString());
            } else {
                str.append(",close=").append(closeInfo.toString());
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
