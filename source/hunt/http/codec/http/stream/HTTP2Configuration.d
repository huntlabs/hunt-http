module hunt.http.codec.http.stream.HTTP2Configuration;

import hunt.http.codec.http.stream.FlowControlStrategy;

import hunt.net.SecureSessionFactory;
import hunt.net.Config;
import hunt.http.codec.http.model.HttpVersion;
// import hunt.net.tcp.secure.conscrypt.ConscryptSecureSessionFactory;

class HTTP2Configuration {

    // TCP settings
    private Config tcpConfiguration; // = new hunt.net.Config();

    // SSL/TLS settings
    private bool _isSecureConnectionEnabled;
    // private SecureSessionFactory secureSessionFactory; // = new ConscryptSecureSessionFactory();

    // HTTP settings
    private int maxDynamicTableSize = 4096;
    private int streamIdleTimeout = 10 * 1000;
    private string flowControlStrategy = "buffer";
    private int initialStreamSendWindow = FlowControlStrategy.DEFAULT_WINDOW_SIZE;
    private int initialSessionRecvWindow = FlowControlStrategy.DEFAULT_WINDOW_SIZE;
    private int maxConcurrentStreams = -1;
    private int maxHeaderBlockFragment = 0;
    private int maxRequestHeadLength = 4 * 1024;
    private int maxRequestTrailerLength = 4 * 1024;
    private int maxResponseHeadLength = 4 * 1024;
    private int maxResponseTrailerLength = 4 * 1024;
    private string characterEncoding = "UTF-8";
    private string protocol; // HTTP/2.0, HTTP/1.1
    private int http2PingInterval = 10 * 1000;

    // WebSocket settings
    private int websocketPingInterval = 10 * 1000;

    this()
    {
        // secureSessionFactory = new ConscryptSecureSessionFactory();
        tcpConfiguration = new hunt.net.Config.Config();
        protocol = HttpVersion.HTTP_1_1.asString();
    }

    /**
     * Get the TCP configuration.
     *
     * @return The TCP configuration.
     */
    hunt.net.Config.Config getTcpConfiguration() {
        return tcpConfiguration;
    }

    /**
     * Set the TCP configuration.
     *
     * @param tcpConfiguration The TCP configuration.
     */
    void setTcpConfiguration(hunt.net.Config.Config tcpConfiguration) {
        this.tcpConfiguration = tcpConfiguration;
    }

    /**
     * Get the max dynamic table size of HTTP2 protocol.
     *
     * @return The max dynamic table size of HTTP2 protocol.
     */
    int getMaxDynamicTableSize() {
        return maxDynamicTableSize;
    }

    /**
     * Set the max dynamic table size of HTTP2 protocol.
     *
     * @param maxDynamicTableSize The max dynamic table size of HTTP2 protocol.
     */
    void setMaxDynamicTableSize(int maxDynamicTableSize) {
        this.maxDynamicTableSize = maxDynamicTableSize;
    }

    /**
     * Get the HTTP2 stream idle timeout. The time unit is millisecond.
     *
     * @return The HTTP2 stream idle timeout. The time unit is millisecond.
     */
    int getStreamIdleTimeout() {
        return streamIdleTimeout;
    }

    /**
     * Set the HTTP2 stream idle timeout. The time unit is millisecond.
     *
     * @param streamIdleTimeout The HTTP2 stream idle timeout. The time unit is millisecond.
     */
    void setStreamIdleTimeout(int streamIdleTimeout) {
        this.streamIdleTimeout = streamIdleTimeout;
    }

    /**
     * Get the HTTP2 flow control strategy. The value is "simple" or "buffer".
     * If you use the "simple" flow control strategy, once the server or client receives the data, it will send the WindowUpdateFrame.
     * If you use the "buffer" flow control strategy, the server or client will send WindowUpdateFrame when the consumed data exceed the threshold.
     *
     * @return The HTTP2 flow control strategy. The value is "simple" or "buffer".
     */
    string getFlowControlStrategy() {
        return flowControlStrategy;
    }

    /**
     * Set the HTTP2 flow control strategy. The value is "simple" or "buffer".
     * If you use the "simple" flow control strategy, once the server or client receives the data, it will send the WindowUpdateFrame.
     * If you use the "buffer" flow control strategy, the server or client will send WindowUpdateFrame when the consumed data exceed the threshold.
     *
     * @param flowControlStrategy The HTTP2 flow control strategy. The value is "simple" or "buffer".
     */
    void setFlowControlStrategy(string flowControlStrategy) {
        this.flowControlStrategy = flowControlStrategy;
    }

    /**
     * Get the HTTP2 initial receiving window size. The unit is byte.
     *
     * @return the HTTP2 initial receiving window size. The unit is byte.
     */
    int getInitialSessionRecvWindow() {
        return initialSessionRecvWindow;
    }

    /**
     * Set the HTTP2 initial receiving window size. The unit is byte.
     *
     * @param initialSessionRecvWindow The HTTP2 initial receiving window size. The unit is byte.
     */
    void setInitialSessionRecvWindow(int initialSessionRecvWindow) {
        this.initialSessionRecvWindow = initialSessionRecvWindow;
    }

    /**
     * Get the HTTP2 initial sending window size. The unit is byte.
     *
     * @return The HTTP2 initial sending window size. The unit is byte.
     */
    int getInitialStreamSendWindow() {
        return initialStreamSendWindow;
    }

    /**
     * Set the HTTP2 initial sending window size. The unit is byte.
     *
     * @param initialStreamSendWindow the HTTP2 initial sending window size. The unit is byte.
     */
    void setInitialStreamSendWindow(int initialStreamSendWindow) {
        this.initialStreamSendWindow = initialStreamSendWindow;
    }

    /**
     * Get the max concurrent stream size in a HTTP2 session.
     *
     * @return the max concurrent stream size in a HTTP2 session.
     */
    int getMaxConcurrentStreams() {
        return maxConcurrentStreams;
    }

    /**
     * Set the max concurrent stream size in a HTTP2 session.
     *
     * @param maxConcurrentStreams the max concurrent stream size in a HTTP2 session.
     */
    void setMaxConcurrentStreams(int maxConcurrentStreams) {
        this.maxConcurrentStreams = maxConcurrentStreams;
    }

    /**
     * Set the max HTTP2 header block size. If the header block size more the this value,
     * the server or client will split the header buffer to many buffers to send.
     *
     * @return the max HTTP2 header block size.
     */
    int getMaxHeaderBlockFragment() {
        return maxHeaderBlockFragment;
    }

    /**
     * Get the max HTTP2 header block size. If the header block size more the this value,
     * the server or client will split the header buffer to many buffers to send.
     *
     * @param maxHeaderBlockFragment The max HTTP2 header block size.
     */
    void setMaxHeaderBlockFragment(int maxHeaderBlockFragment) {
        this.maxHeaderBlockFragment = maxHeaderBlockFragment;
    }

    /**
     * Get the max HTTP request header size.
     *
     * @return the max HTTP request header size.
     */
    int getMaxRequestHeadLength() {
        return maxRequestHeadLength;
    }

    /**
     * Set the max HTTP request header size.
     *
     * @param maxRequestHeadLength the max HTTP request header size.
     */
    void setMaxRequestHeadLength(int maxRequestHeadLength) {
        this.maxRequestHeadLength = maxRequestHeadLength;
    }

    /**
     * Get the max HTTP response header size.
     *
     * @return the max HTTP response header size.
     */
    int getMaxResponseHeadLength() {
        return maxResponseHeadLength;
    }

    /**
     * Set the max HTTP response header size.
     *
     * @param maxResponseHeadLength the max HTTP response header size.
     */
    void setMaxResponseHeadLength(int maxResponseHeadLength) {
        this.maxResponseHeadLength = maxResponseHeadLength;
    }

    /**
     * Get the max HTTP request trailer size.
     *
     * @return the max HTTP request trailer size.
     */
    int getMaxRequestTrailerLength() {
        return maxRequestTrailerLength;
    }

    /**
     * Set the max HTTP request trailer size.
     *
     * @param maxRequestTrailerLength the max HTTP request trailer size.
     */
    void setMaxRequestTrailerLength(int maxRequestTrailerLength) {
        this.maxRequestTrailerLength = maxRequestTrailerLength;
    }

    /**
     * Get the max HTTP response trailer size.
     *
     * @return the max HTTP response trailer size.
     */
    int getMaxResponseTrailerLength() {
        return maxResponseTrailerLength;
    }

    /**
     * Set the max HTTP response trailer size.
     *
     * @param maxResponseTrailerLength the max HTTP response trailer size.
     */
    void setMaxResponseTrailerLength(int maxResponseTrailerLength) {
        this.maxResponseTrailerLength = maxResponseTrailerLength;
    }

    /**
     * Get the charset of the text HTTP body.
     *
     * @return the charset of the text HTTP body.
     */
    string getCharacterEncoding() {
        return characterEncoding;
    }

    /**
     * Set the charset of the text HTTP body.
     *
     * @param characterEncoding the charset of the text HTTP body.
     */
    void setCharacterEncoding(string characterEncoding) {
        this.characterEncoding = characterEncoding;
    }

    /**
     * If return true, the server or client enable the SSL/TLS connection.
     *
     * @return If return true, the server or client enable the SSL/TLS connection.
     */
    bool isSecureConnectionEnabled() {
        return _isSecureConnectionEnabled;
    }

    /**
     * If set true, the server or client enable the SSL/TLS connection.
     *
     * @param isSecureConnectionEnabled If set true, the server or client enable the SSL/TLS connection.
     */
    void setSecureConnectionEnabled(bool status) {
        this._isSecureConnectionEnabled = status;
    }

    /**
     * Get the SSL/TLS connection factory.
     *
     * @return the SSL/TLS connection factory.
     */
    // SecureSessionFactory getSecureSessionFactory() {
    //     return secureSessionFactory;
    // }

    /**
     * Set the SSL/TLS connection factory.
     *
     * @param secureSessionFactory the SSL/TLS connection factory.
     */
    // void setSecureSessionFactory(SecureSessionFactory secureSessionFactory) {
    //     this.secureSessionFactory = secureSessionFactory;
    // }

    /**
     * Get the default HTTP protocol version. The value is "HTTP/2.0" or "HTTP/1.1". If the value is null,
     * the server or client will negotiate a HTTP protocol version using ALPN.
     *
     * @return the default HTTP protocol version. The value is "HTTP/2.0" or "HTTP/1.1".
     */
    string getProtocol() {
        return protocol;
    }

    /**
     * Set the default HTTP protocol version. The value is "HTTP/2.0" or "HTTP/1.1". If the value is null,
     * the server or client will negotiate a HTTP protocol version using ALPN.
     *
     * @param protocol the default HTTP protocol version. The value is "HTTP/2.0" or "HTTP/1.1".
     */
    void setProtocol(string protocol) {
        this.protocol = protocol;
    }

    /**
     * Get the HTTP2 connection sending ping frame interval. The time unit is millisecond.
     *
     * @return the sending ping frame interval. The time unit is millisecond.
     */
    int getHttp2PingInterval() {
        return http2PingInterval;
    }

    /**
     * Set the sending ping frame interval. The time unit is millisecond.
     *
     * @param http2PingInterval the sending ping frame interval. The time unit is millisecond.
     */
    void setHttp2PingInterval(int http2PingInterval) {
        this.http2PingInterval = http2PingInterval;
    }

    /**
     * Get the WebSocket connection sending ping frame interval. The time unit is millisecond.
     *
     * @return the WebSocket connection sending ping frame interval. The time unit is millisecond.
     */
    int getWebsocketPingInterval() {
        return websocketPingInterval;
    }

    /**
     * Set the WebSocket connection sending ping frame interval. The time unit is millisecond.
     *
     * @param websocketPingInterval the WebSocket connection sending ping frame interval. The time unit is millisecond.
     */
    void setWebsocketPingInterval(int websocketPingInterval) {
        this.websocketPingInterval = websocketPingInterval;
    }
}
