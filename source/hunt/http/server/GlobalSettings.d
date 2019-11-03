module hunt.http.server.GlobalSettings;

import hunt.http.server.HttpServerOptions;
import hunt.http.server.HttpRequestOptions;
import hunt.http.MultipartOptions;

import std.concurrency : initOnce;

/**
 * 
 */
struct GlobalSettings {

    __gshared HttpServerOptions httpServerOptions;

    static MultipartOptions getMultipartOptions(HttpRequestOptions options) {
        __gshared MultipartOptions _opt;
        assert(options !is null);
        
        return initOnce!_opt( 
                new MultipartOptions(options.getTempFileAbsolutePath(), 
                    options.getMaxFileSize(), options.getMaxRequestSize(), 
                    options.getBodyBufferThreshold())
            );
    }

    shared static this() {
        httpServerOptions = new HttpServerOptions();
    }
}
