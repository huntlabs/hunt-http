module hunt.http.WebSocketConnection;

import hunt.http.HttpRequest;
import hunt.http.HttpResponse;
import hunt.http.codec.websocket.stream.IOState;
import hunt.http.WebSocketFrame;
import hunt.http.WebSocketPolicy;
import hunt.http.HttpConnection;

import hunt.io.ByteBuffer;
import hunt.concurrency.FuturePromise;
import hunt.Exceptions;
import hunt.Functions;
import hunt.logging;
import hunt.net.Connection;
import hunt.util.Common;


deprecated("Using WebSocketConnectionState instead.")
alias ConnectionState = WebSocketConnectionState;

/**
 * Connection states as outlined in <a href="https://tools.ietf.org/html/rfc6455">RFC6455</a>.
 */
enum WebSocketConnectionState {
    Unknown,
    
    /**
     * [RFC] Initial state of a connection, the upgrade request / response is in progress
     */
    CONNECTING,
    /**
     * [Impl] Intermediate state between CONNECTING and OPEN, used to indicate that a upgrade request/response is successful, but the end-user provided socket's
     * onOpen code has yet to run.
     * <p>
     * This state is to allow the local socket to initiate messages and frames, but to NOT start reading yet.
     */
    CONNECTED,
    /**
     * [RFC] The websocket connection is established and open.
     * <p>
     * This indicates that the Upgrade has succeed, and the end-user provided socket's onOpen code has completed.
     * <p>
     * It is now time to start reading from the remote endpoint.
     */
    OPEN,
    /**
     * [RFC] The websocket closing handshake is started.
     * <p>
     * This can be considered a half-closed state.
     * <p>
     * When receiving this as an event on {@link ConnectionStateListener#onConnectionStateChange(ConnectionState)} a close frame should be sent using
     * the {@link CloseInfo} available from {@link IOState#getCloseInfo()}
     */
    CLOSING,
    /**
     * [RFC] The websocket connection is closed.
     * <p>
     * Connection should be disconnected and no further reads or writes should occur.
     */
    CLOSED
}


/**
 * Interface for dealing with Incoming Frames.
 */
interface IncomingFrames {
    
    void incomingError(Exception t);

    /**
     * Process the incoming frame.
     * <p>
     * Note: if you need to hang onto any information from the frame, be sure
     * to copy it, as the information contained in the Frame will be released
     * and/or reused by the implementation.
     *
     * @param frame the frame to process
     */
    void incomingFrame(WebSocketFrame frame);
}


/**
 * Interface for dealing with frames outgoing to (eventually) the network layer.
 */
interface OutgoingFrames {
    /**
     * A frame, and optional callback, intended for the network layer.
     * <p>
     * Note: the frame can undergo many transformations in the various
     * layers and extensions present in the implementation.
     * <p>
     * If you are implementing a mutation, you are obliged to handle
     * the incoming WriteCallback appropriately.
     *
     * @param frame    the frame to eventually write to the network layer.
     * @param callback the callback to notify when the frame is written.
     */
    void outgoingFrame(WebSocketFrame frame, Callback callback);

}


/**
 * 
 */
interface WebSocketConnection : OutgoingFrames, HttpConnection {

    /**
     * Register the connection close callback.
     *
     * @param closedListener The connection close callback.
     * @return The WebSocket connection.
     */
    // WebSocketConnection onClose(Action1!(WebSocketConnection) closedListener);

    /**
     * Register the exception callback.
     *
     * @param exceptionListener The exception callback.
     * @return The WebSocket connection.
     */
    // WebSocketConnection onException(Action2!(WebSocketConnection, Exception) exceptionListener);

    /**
     * Get the read/write idle timeout.
     *
     * @return the idle timeout in milliseconds
     */
    // long getIdleTimeout();

    bool isConnected();

    /**
     * Get the IOState of the connection.
     *
     * @return the IOState of the connection.
     */
    IOState getIOState();

    /**
     * The policy that the connection is running under.
     *
     * @return the policy for the connection
     */
    WebSocketPolicy getPolicy();

    /**
     * Generate random 4bytes mask key
     *
     * @return the mask key
     */
    byte[] generateMask();

    /**
     * Send text message.
     *
     * @param text The text message.
     * @return The future result.
     */
    FuturePromise!(bool) sendText(string text);

    /**
     * Send binary message.
     *
     * @param data The binary message.
     * @return The future result.
     */
    FuturePromise!(bool) sendData(byte[] data);

    /**
     * Send binary message.
     *
     * @param data The binary message.
     * @return The future result.
     */
    FuturePromise!(bool) sendData(ByteBuffer data);

    /**
     * Get the websocket upgrade request.
     *
     * @return The upgrade request.
     */
    HttpRequest getUpgradeRequest();

    /**
     * Get the websocket upgrade response.
     *
     * @return The upgrade response.
     */
    HttpResponse getUpgradeResponse();

    final string getPath() {
        return getUpgradeRequest().getURI().getPath();
    }

}


/**
 * 
 */
interface WebSocketMessageHandler {

    void onOpen(WebSocketConnection connection);

    void onClosed(WebSocketConnection connection); // CloseStatus closeStatus

    void onPing(WebSocketConnection connection);

    void onPong(WebSocketConnection connection);
    
    void onText(WebSocketConnection connection, string text);

    void onBinary(WebSocketConnection connection, ByteBuffer buffer);

    void onContinuation(WebSocketConnection connection, ByteBuffer buffer);

    void onError(WebSocketConnection connection, Exception exception);

    alias onFailure = onError;
}

/**
 * See_Also:
 *  WebSocketListener from OKHTTP3
 */
abstract class AbstractWebSocketMessageHandler : WebSocketMessageHandler {

    void onOpen(WebSocketConnection connection)  { implementationMissing(false); }

    void onClosed(WebSocketConnection connection)  { 
        version(HUNT_HTTP_DEBUG) infof("closed with %s", connection.getRemoteAddress());
    }

    void onPing(WebSocketConnection connection)  { 
        version(HUNT_HTTP_DEBUG) tracef("ping from %s", connection.getRemoteAddress()); 
    }

    void onPong(WebSocketConnection connection)  { 
        version(HUNT_HTTP_DEBUG) tracef("ping from %s", connection.getRemoteAddress());
    }
    
    void onText(WebSocketConnection connection, string text)  { 
        version(HUNT_HTTP_DEBUG) tracef("received (from %s): %s", connection.getRemoteAddress(), text); 
     }

    void onBinary(WebSocketConnection connection, ByteBuffer buffer)  { implementationMissing(false); }

    void onContinuation(WebSocketConnection connection, ByteBuffer buffer)  { implementationMissing(false); }

    void onError(WebSocketConnection connection, Exception ex)  { 
        debug warningf("error (from %s): %s", connection.getRemoteAddress(), ex.msg);
        version(HUNT_DEBUG) warning(ex);
    }
}
