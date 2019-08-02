module hunt.http.client.Call;

import hunt.Exceptions;

import hunt.http.client.HttpClientResponse;
import hunt.http.client.HttpClientRequest;



/**
 * A call is a request that has been prepared for execution. A call can be canceled. As this object
 * represents a single request/response pair (stream), it cannot be executed twice.
 */
interface Call {
    /** Returns the original request that initiated this call. */
    Request request();

    /**
     * Invokes the request immediately, and blocks until the response can be processed or is in
     * error.
     *
     * <p>To avoid leaking resources callers should close the {@link Response} which in turn will
     * close the underlying {@link ResponseBody}.
     *
     * <pre>{@code
     *
     *   // ensure the response (and underlying response body) is closed
     *   try (Response response = client.newCall(request).execute()) {
     *     ...
     *   }
     *
     * }</pre>
     *
     * <p>The caller may read the response body with the response's {@link Response#body} method. To
     * avoid leaking resources callers must {@linkplain ResponseBody close the response body} or the
     * Response.
     *
     * <p>Note that transport-layer success (receiving a HTTP response code, headers and body) does
     * not necessarily indicate application-layer success: {@code response} may still indicate an
     * unhappy HTTP response code like 404 or 500.
     *
     * @throws IOException if the request could not be executed due to cancellation, a connectivity
     * problem or timeout. Because networks can fail during an exchange, it is possible that the
     * remote server accepted the request before the failure.
     * @throws IllegalStateException when the call has already been executed.
     */
    Response execute();

    /**
     * Schedules the request to be executed at some point in the future.
     *
     * <p>The {@link OkHttpClient#dispatcher dispatcher} defines when the request will run: usually
     * immediately unless there are several other requests currently being executed.
     *
     * <p>This client will later call back {@code responseCallback} with either an HTTP response or a
     * failure exception.
     *
     * @throws IllegalStateException when the call has already been executed.
     */
    void enqueue(Callback responseCallback);

    /** Cancels the request, if possible. Requests that are already complete cannot be canceled. */
    void cancel();

    /**
     * Returns true if this call has been either {@linkplain #execute() executed} or {@linkplain
     * #enqueue(Callback) enqueued}. It is an error to execute a call more than once.
     */
    bool isExecuted();

    bool isCanceled();

    /**
     * Returns a timeout that spans the entire call: resolving DNS, connecting, writing the request
     * body, server processing, and reading the response body. If the call requires redirects or
     * retries all must complete within one timeout period.
     *
     * <p>Configure the client's default timeout with {@link OkHttpClient.Builder#callTimeout}.
     */
//   Timeout timeout();

    /**
     * Create a new, identical call to this one which can be enqueued or executed even if this call
     * has already been.
     */
//   Call clone();


}

interface CallFactory {
        Call newCall(Request request);
}


interface Callback {
    /**
     * Called when the request could not be executed due to cancellation, a connectivity problem or
     * timeout. Because networks can fail during an exchange, it is possible that the remote server
     * accepted the request before the failure.
     */
    void onFailure(Call call, IOException e);

    /**
     * Called when the HTTP response was successfully returned by the remote server. The callback may
     * proceed to read the response body with {@link Response#body}. The response is still live until
     * its response body is {@linkplain ResponseBody closed}. The recipient of the callback may
     * consume the response body on another thread.
     *
     * <p>Note that transport-layer success (receiving a HTTP response code, headers and body) does
     * not necessarily indicate application-layer success: {@code response} may still indicate an
     * unhappy HTTP response code like 404 or 500.
     */
    void onResponse(Call call, Response response);
}
