module hunt.http.server.http.router.RoutingContext;

import hunt.http.server.http.router.HTTPSession;

import hunt.http.codec.http.model;
import hunt.http.server.http.SimpleRequest;
import hunt.http.server.http.SimpleResponse;
import hunt.http.server.http.router.handler.error.DefaultErrorResponseHandlerLoader;

import hunt.util.concurrent.Promise;
import hunt.util.functional;
import hunt.util.common;

import hunt.container;

import std.conv;


/**
 * A new RoutingContext(ctx) instance is created for each HTTP request.
 * <p>
 * You can visit the RoutingContext instance in the whole router chain.
 * It provides HTTP request/response API and allows you to maintain arbitrary data that lives for the lifetime of the context.
 * Contexts are discarded once they have been routed to the handler for the request.
 * <p>
 * The context also provides access to the Session, cookies and body for the request, given the correct handlers in the application.
 *
 * 
 */
// interface RoutingContext : Closeable {

//     Object getAttribute(string key);

//     Object setAttribute(string key, Object value);

//     Object removeAttribute(string key);

//     HashMap!(string, Object) getAttributes();

//     SimpleResponse getResponse();

//     SimpleResponse getAsyncResponse();

//     SimpleRequest getRequest();

//     int getConnectionId();

//     string getRouterParameter(string name);

//     string getWildcardMatchedResult(int index);

//     string getRegexGroup(int index);

//     string getPathParameter(string name);

//     // string getRouterParamOpt(string name) {
//     //     return getRouterParameter(name);
//     // }

//     /**
//      * Set the HTTP body packet receiving callback.
//      *
//      * @param content The HTTP body data receiving callback. When the server receives the HTTP body packet, it will be called.
//      * @return RoutingContext
//      */
//     RoutingContext content(Action1!ByteBuffer content);

//     /**
//      * Set the HTTP body packet complete callback.
//      *
//      * @param contentComplete The HTTP body packet complete callback.
//      * @return RoutingContext
//      */
//     RoutingContext contentComplete(Action1!(SimpleRequest) contentComplete);

//     /**
//      * Set the HTTP message complete callback.
//      *
//      * @param messageComplete the HTTP message complete callback.
//      * @return RoutingContext
//      */
//     RoutingContext messageComplete(Action1!(SimpleRequest) messageComplete);

//     /**
//      * If return true, it represents you has set a HTTP body data receiving callback.
//      *
//      * @return If return true, it represents you has set a HTTP body data receiving callback
//      */
//     bool isAsynchronousRead();

//     /**
//      * Execute the next handler.
//      *
//      * @return If return false, it represents current handler is the last.
//      */
//     bool next();

//     /**
//      * If return false, it represents current handler is the last.
//      *
//      * @return If return false, it represents current handler is the last.
//      */
//     bool hasNext();

//     // <T> RoutingContext complete(Promise<T> promise);

//     // <T> bool next(Promise<T> promise);

//     // <T> CompletableFuture<T> nextFuture() {
//     //     Promise.Completable<T> completable = new Promise.Completable<>();
//     //     next(completable);
//     //     return completable;
//     // }

//     // <T> CompletableFuture<T> complete() {
//     //     Promise.Completable<T> completable = new Promise.Completable<>();
//     //     complete(completable);
//     //     return completable;
//     // }

    // void succeed(bool t);

    // void fail(Exception x);


//     // request wrap
//     string getMethod();

//     HttpURI getURI();

//     HttpVersion getHttpVersion();

//     HttpFields getFields();

//     long getContentLength();

//     List!Cookie getCookies();

//     // response wrap
//     RoutingContext setStatus(int status);

//     RoutingContext setReason(string reason);

//     RoutingContext setHttpVersion(HttpVersion httpVersion) {
//         getResponse().setHttpVersion(httpVersion);
//         return this;
//     }

//     RoutingContext put(HttpHeader header, string value) {
//         getResponse().put(header, value);
//         return this;
//     }

//     RoutingContext put(string header, string value) {
//         getResponse().put(header, value);
//         return this;
//     }

//     RoutingContext add(HttpHeader header, string value) {
//         getResponse().add(header, value);
//         return this;
//     }

//     RoutingContext add(string name, string value) {
//         getResponse().add(name, value);
//         return this;
//     }

//     RoutingContext addCookie(Cookie cookie) {
//         getResponse().addCookie(cookie);
//         return this;
//     }

//     RoutingContext write(string value) {
//         getResponse().write(value);
//         return this;
//     }

//     RoutingContext writeJson(Object object) {
//         put(HttpHeader.CONTENT_TYPE, MimeTypes.Type.APPLICATION_JSON_UTF_8.asString()).write(Json.toJson(object));
//         return this;
//     }

//     RoutingContext end(string value) {
//         return write(value).end();
//     }

//     RoutingContext end() {
//         getResponse().end();
//         return this;
//     }

//     RoutingContext write(byte[] b, int off, int len) {
//         getResponse().write(b, off, len);
//         return this;
//     }

//     RoutingContext write(byte[] b) {
//         return write(b, 0, b.length);
//     }

//     RoutingContext end(byte[] b) {
//         return write(b).end();
//     }

//     void redirect(string url) {
//         setStatus(HttpStatus.FOUND_302).put(HttpHeader.LOCATION, url);
//         DefaultErrorResponseHandlerLoader.getInstance().getHandler().render(this, HttpStatus.FOUND_302, null);
//     }

//     // HTTP body API
//     string getParameter(string name);

//     Optional!string getParamOpt(string name) {
//         return Optional.ofNullable(getParameter(name));
//     }

//     List!string getParameterValues(string name);

//     Map!(string, List!string) getParameterMap();

//     Collection<Part> getParts();

//     Part getPart(string name);

//     InputStream getInputStream();

//     BufferedReader getBufferedReader();

//     string getStringBody(string charset);

//     string getStringBody();

//     <T> T getJsonBody(Class<T> clazz);

//     <T> T getJsonBody(GenericTypeReference<T> typeReference);

//     JsonObject getJsonObjectBody();

//     JsonArray getJsonArrayBody();


//     // HTTP session API
//     HTTPSession getSessionNow() {
//         return getSession().getNow(null);
//     }

//     HTTPSession getSessionNow(bool create) {
//         return getSession(create).getNow(null);
//     }

//     int getSessionSizeNow() {
//         return getSessionSize().getNow(0);
//     }

//     bool removeSessionNow() {
//         return removeSession().getNow(false);
//     }

//     bool updateSessionNow(HTTPSession httpSession) {
//         return updateSession(httpSession).getNow(false);
//     }

//     CompletableFuture<HTTPSession> getSessionById(string id);

    HTTPSession getSession();

//     CompletableFuture<HTTPSession> getSession(bool create);

//     CompletableFuture<HTTPSession> getAndCreateSession(int maxAge);

    int getSessionSize();

//     CompletableFuture<bool> removeSessionById(string id);
    
    bool removeSession();

//     CompletableFuture<bool> updateSession(HTTPSession httpSession);

//     bool isRequestedSessionIdFromURL();

//     bool isRequestedSessionIdFromCookie();

//     string getRequestedSessionId();

//     string getSessionIdParameterName();

//     // Template API
//     void renderTemplate(string resourceName, Object scope);

//     void renderTemplate(string resourceName, Object[] scopes);

//     void renderTemplate(string resourceName, List!Object scopes);

//     void renderTemplate(string resourceName) {
//         renderTemplate(resourceName, Collections.emptyList());
//     }

// }


abstract class RoutingContext : Closeable {

    string getAttribute(string key);

    string setAttribute(string key, string value);

    string removeAttribute(string key);

    string[string] getAttributes();

    SimpleResponse getResponse();

    SimpleResponse getAsyncResponse();

    SimpleRequest getRequest();

    int getConnectionId() {
        return getRequest().getConnection().getSessionId();
    }

    string getRouterParameter(string name);

    string getWildcardMatchedResult(int index) {
        return getRouterParameter("param" ~ index.to!string());
    }

    string getRegexGroup(int index) {
        return getRouterParameter("group" ~ index.to!string());
    }

    string getPathParameter(string name) {
        return getRouterParameter(name);
    }

    // Optional!string getRouterParamOpt(string name) {
    //     return Optional.ofNullable(getRouterParameter(name));
    // }

    /**
     * Set the HTTP body packet receiving callback.
     *
     * @param content The HTTP body data receiving callback. When the server receives the HTTP body packet, it will be called.
     * @return RoutingContext
     */
    RoutingContext onContent(Action1!ByteBuffer content);

    /**
     * Set the HTTP body packet complete callback.
     *
     * @param contentComplete The HTTP body packet complete callback.
     * @return RoutingContext
     */
    RoutingContext onContentComplete(Action1!(SimpleRequest) contentComplete);

    /**
     * Set the HTTP message complete callback.
     *
     * @param messageComplete the HTTP message complete callback.
     * @return RoutingContext
     */
    RoutingContext onMessageComplete(Action1!(SimpleRequest) messageComplete);

    /**
     * If return true, it represents you has set a HTTP body data receiving callback.
     *
     * @return If return true, it represents you has set a HTTP body data receiving callback
     */
    bool isAsynchronousRead();

    /**
     * Execute the next handler.
     *
     * @return If return false, it represents current handler is the last.
     */
    bool next();

    /**
     * If return false, it represents current handler is the last.
     *
     * @return If return false, it represents current handler is the last.
     */
    bool hasNext();

    // <T> RoutingContext complete(Promise<T> promise);

    // <T> bool next(Promise<T> promise);

    // <T> CompletableFuture<T> nextFuture() {
    //     Promise.Completable<T> completable = new Promise.Completable<>();
    //     next(completable);
    //     return completable;
    // }

    // <T> CompletableFuture<T> complete() {
    //     Promise.Completable<T> completable = new Promise.Completable<>();
    //     complete(completable);
    //     return completable;
    // }

    
    void succeed(bool t);

    void fail(Exception x);


    // request wrap
    string getMethod() {
        return getRequest().getMethod();
    }

    HttpURI getURI() {
        return getRequest().getURI();
    }

    HttpVersion getHttpVersion() {
        return getRequest().getHttpVersion();
    }

    HttpFields getFields() {
        return getRequest().getFields();
    }

    long getContentLength() {
        return getRequest().getContentLength();
    }

    List!(Cookie) getCookies() {
        return getRequest().getCookies();
    }


    // response wrap
    RoutingContext setStatus(int status) {
        getResponse().setStatus(status);
        return this;
    }

    RoutingContext setReason(string reason) {
        getResponse().setReason(reason);
        return this;
    }

    RoutingContext setHttpVersion(HttpVersion httpVersion) {
        getResponse().setHttpVersion(httpVersion);
        return this;
    }

    RoutingContext put(HttpHeader header, string value) {
        getResponse().put(header, value);
        return this;
    }

    RoutingContext put(string header, string value) {
        getResponse().put(header, value);
        return this;
    }

    RoutingContext add(HttpHeader header, string value) {
        getResponse().add(header, value);
        return this;
    }

    RoutingContext add(string name, string value) {
        getResponse().add(name, value);
        return this;
    }

    RoutingContext addCookie(Cookie cookie) {
        getResponse().addCookie(cookie);
        return this;
    }

    RoutingContext write(string value) {
        getResponse().write(value);
        return this;
    }

    // RoutingContext writeJson(Object object) {
    //     put(HttpHeader.CONTENT_TYPE, MimeTypes.Type.APPLICATION_JSON_UTF_8.asString()).write(Json.toJson(object));
    //     return this;
    // }

    RoutingContext end(string value) {
        return write(value).end();
    }

    RoutingContext end() {
        getResponse().end();
        return this;
    }

    RoutingContext write(byte[] b, int off, int len) {
        getResponse().write(b, off, len);
        return this;
    }

    RoutingContext write(byte[] b) {
        return write(b, 0, cast(int)b.length);
    }

    RoutingContext end(byte[] b) {
        return write(b).end();
    }

    void redirect(string url) {
        setStatus(HttpStatus.FOUND_302).put(HttpHeader.LOCATION, url);
        DefaultErrorResponseHandlerLoader.getInstance().getHandler().render(this, HttpStatus.FOUND_302, null);
    }

    // HTTP body API
    string getParameter(string name);

    // Optional!string getParamOpt(string name) {
    //     return Optional.ofNullable(getParameter(name));
    // }

    List!string getParameterValues(string name);

    Map!(string, List!string) getParameterMap();

    // Collection!Part getParts();

    // Part getPart(string name);

    // InputStream getInputStream();

    // BufferedReader getBufferedReader();

    string getStringBody(string charset);

    string getStringBody();

    // <T> T getJsonBody(Class<T> clazz);

    // <T> T getJsonBody(GenericTypeReference<T> typeReference);

    // JsonObject getJsonObjectBody();

    // JsonArray getJsonArrayBody();


    // HTTP session API
    // HTTPSession getSessionNow() {
    //     return getSession();
    // }

    // HTTPSession getSessionNow(bool create) {
    //     return getSession(create).getNow(null);
    // }

    // int getSessionSizeNow() {
    //     return getSessionSize().getNow(0);
    // }

    // bool removeSessionNow() {
    //     return removeSession().getNow(false);
    // }

    // bool updateSessionNow(HTTPSession httpSession) {
    //     return updateSession(httpSession).getNow(false);
    // }

    // CompletableFuture<HTTPSession> getSessionById(string id);

    // CompletableFuture<HTTPSession> getSession();

    // CompletableFuture<HTTPSession> getSession(bool create);

    // CompletableFuture<HTTPSession> getAndCreateSession(int maxAge);

    // CompletableFuture<int> getSessionSize();

    // CompletableFuture<bool> removeSessionById(string id);
    
    // CompletableFuture<bool> removeSession();

    // CompletableFuture<bool> updateSession(HTTPSession httpSession);

    bool isRequestedSessionIdFromURL();

    bool isRequestedSessionIdFromCookie();

    string getRequestedSessionId();

    string getSessionIdParameterName();

    // Template API
    // void renderTemplate(string resourceName, Object scope);

    // void renderTemplate(string resourceName, Object[] scopes);

    // void renderTemplate(string resourceName, List!Object scopes);

    // void renderTemplate(string resourceName) {
    //     renderTemplate(resourceName, Collections.emptyList());
    // }

}
