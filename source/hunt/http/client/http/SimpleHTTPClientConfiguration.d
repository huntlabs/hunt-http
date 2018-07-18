module hunt.http.client.http.SimpleHTTPClientConfiguration;

import hunt.http.codec.http.stream.HTTP2Configuration;
// import hunt.http.utils.ServiceUtils;
// import hunt.http.utils.heartbeat.HealthCheck;

/**
 * 
 */
class SimpleHTTPClientConfiguration : HTTP2Configuration {

    enum int defaultPoolSize = 16; // Integer.getInteger("hunt.http.client.http.connection.defaultPoolSize", 16);
    enum long defaultConnectTimeout = 10 * 1000L; // Long.getLong("hunt.http.client.http.connection.defaultConnectTimeout", 10 * 1000L);

    private int poolSize = defaultPoolSize;
    private long connectTimeout = defaultConnectTimeout;
    // private HealthCheck healthCheck = ServiceUtils.loadService(HealthCheck.class, new HealthCheck());

    /**
     * Get the HTTP client connection pool size.
     *
     * @return The HTTP client connection pool size.
     */
    int getPoolSize() {
        return poolSize;
    }

    /**
     * Set the HTTP client connection pool size.
     *
     * @param poolSize The HTTP client connection pool size
     */
    void setPoolSize(int poolSize) {
        this.poolSize = poolSize;
    }

    /**
     * Get the connecting timeout. The time unit is millisecond.
     *
     * @return The connecting timeout. The time unit is millisecond.
     */
    long getConnectTimeout() {
        return connectTimeout;
    }

    /**
     * Set the connecting timeout. The time unit is millisecond.
     *
     * @param connectTimeout The connecting timeout. The time unit is millisecond.
     */
    void setConnectTimeout(long connectTimeout) {
        this.connectTimeout = connectTimeout;
    }

    /**
     * Get the HealthCheck. It checks the HTTP client connection is alive.
     *
     * @return the HealthCheck.
     */
    // HealthCheck getHealthCheck() {
    //     return healthCheck;
    // }

    /**
     * Set the HealthCheck. It checks the HTTP client connection is alive.
     *
     * @param healthCheck the HealthCheck.
     */
    // void setHealthCheck(HealthCheck healthCheck) {
    //     this.healthCheck = healthCheck;
    // }
}
