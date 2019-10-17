module hunt.http.server.GlobalSettings;

import hunt.http.server.HttpServerOptions;

struct GlobalSettings {
    __gshared HttpServerOptions httpServerOptions;

    shared static this() {
        httpServerOptions = new HttpServerOptions();
    }
}
