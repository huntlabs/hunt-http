module hunt.http.router.RoutingContext;

import hunt.http.router.HttpSession;
import hunt.http.server.HttpServerRequest;

import hunt.http.codec.http.model;
import hunt.http.codec.http.stream.HttpOutputStream;
import hunt.http.router.handler.DefaultErrorResponseHandler;

import hunt.concurrency.Promise;
import hunt.Exceptions;
import hunt.Functions;
import hunt.logging.ConsoleLogger;
import hunt.util.Common;

import hunt.collection.ByteBuffer;
import hunt.collection.List;
import hunt.collection.Map;

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
abstract class RoutingContext : Closeable {

    // string getAttribute(string key) { implementationMissing(false); return null;}

    // string setAttribute(string key, string value) { implementationMissing(false); return null;}

    // string removeAttribute(string key) { implementationMissing(false); return null;}

    // string[string] getAttributes() { implementationMissing(false); return null;}

    HttpResponse getResponse();

    // HttpResponse getAsyncResponse() { implementationMissing(false); return null;}

    HttpServerRequest getRequest();

    // HttpOutputStream getOutputStream();   

    int getConnectionId();

    // void setHttpBody(HttpServerRequest requestBody);

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
    // RoutingContext onContent(Action1!ByteBuffer content); // { implementationMissing(false); return null;}

    /**
     * Set the HTTP body packet complete callback.
     *
     * @param contentComplete The HTTP body packet complete callback.
     * @return RoutingContext
     */
    // RoutingContext onContentComplete(Action1!(HttpRequest) contentComplete); // { implementationMissing(false); return null;}

    /**
     * Set the HTTP message complete callback.
     *
     * @param messageComplete the HTTP message complete callback.
     * @return RoutingContext
     */
    // RoutingContext onMessageComplete(Action1!(HttpRequest) messageComplete); // { implementationMissing(false); return null;}

    /**
     * If return true, it represents you has set a HTTP body data receiving callback.
     *
     * @return If return true, it represents you has set a HTTP body data receiving callback
     */
    bool isAsynchronousRead();
    void enableAsynchronousRead();

    /**
     * Execute the next handler.
     *
     * @return If return false, it represents current handler is the last.
     */
    bool next() { implementationMissing(false); return false;}

    /**
     * If return false, it represents current handler is the last.
     *
     * @return If return false, it represents current handler is the last.
     */
    bool hasNext() { implementationMissing(false); return false;}

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

    
    void succeed(bool t) { 
        version(HUNT_HTTP_DEBUG) trace("do nothing");
    }

    void fail(Exception x) { 
        version(HUNT_DEBUG) warning(x);
    }


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

    // Cookie[] getCookies() {
    //     return getRequest().getCookies();
    // }


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

    // RoutingContext put(HttpHeader header, string value) {
    //     getResponse().getFields().put(header, value);
    //     return this;
    // }

    // RoutingContext put(string header, string value) {
    //     getResponse().getFields().put(header, value);
    //     return this;
    // }

    // RoutingContext add(HttpHeader header, string value) {
    //     getResponse().getFields().add(header, value);
    //     return this;
    // }

    // RoutingContext add(string name, string value) {
    //     getResponse().getFields().add(name, value);
    //     return this;
    // }

    HttpFields getResponseHeaders() {
        return getResponse().getFields();
    }

    // RoutingContext addCookie(Cookie cookie) {
    //     getResponse().addCookie(cookie);
    //     return this;
    // }

    RoutingContext write(string value);

    // RoutingContext writeJson(Object object) {
    //     put(HttpHeader.CONTENT_TYPE, MimeTypes.Type.APPLICATION_JSON_UTF_8.asString()).write(Json.toJson(object));
    //     return this;
    // }

    RoutingContext write(byte[] b, int off, int len);

    RoutingContext write(byte[] b) {
        return write(b, 0, cast(int)b.length);
    }

    RoutingContext end(string value) {
        return write(value).end();
    }

    RoutingContext end();

    RoutingContext end(byte[] b) {
        return write(b).end();
    }

    void flush();

    bool isCommitted();

    void redirect(string url) {
        setStatus(HttpStatus.FOUND_302);
        getResponseHeaders().put(HttpHeader.LOCATION, url);
        DefaultErrorResponseHandler.Default().render(this, HttpStatus.FOUND_302, null);
    }

    // HTTP body API
    string getParameter(string name)  { implementationMissing(false); return null; }

    // Optional!string getParamOpt(string name) {
    //     return Optional.ofNullable(getParameter(name));
    // }

    List!string getParameterValues(string name) { implementationMissing(false); return null; }

    Map!(string, List!string) getParameterMap() { implementationMissing(false); return null; }

    // Collection!Part getParts();

    // Part getPart(string name);

    // InputStream getInputStream();

    // BufferedReader getBufferedReader();

    string getStringBody(string charset); // { implementationMissing(false); return null; }

    string getStringBody(); // { implementationMissing(false); return null; }

    // <T> T getJsonBody(Class<T> clazz);

    // <T> T getJsonBody(GenericTypeReference<T> typeReference);

    // JsonObject getJsonObjectBody();

    // JsonArray getJsonArrayBody();


    // HTTP session API
    // HttpSession getSessionNow() {
    //     return getSession();
    // }

    // HttpSession getSessionNow(bool create) {
    //     return getSession(create).getNow(null);
    // }

    // int getSessionSizeNow() {
    //     return getSessionSize().getNow(0);
    // }

    // bool removeSessionNow() {
    //     return removeSession().getNow(false);
    // }

    // bool updateSessionNow(HttpSession httpSession) {
    //     return updateSession(httpSession).getNow(false);
    // }

    // CompletableFuture<HttpSession> getSessionById(string id);

    // CompletableFuture<HttpSession> getSession();

    // CompletableFuture<HttpSession> getSession(bool create);

    // CompletableFuture<HttpSession> getAndCreateSession(int maxAge);

    // CompletableFuture<int> getSessionSize();

    // CompletableFuture<bool> removeSessionById(string id);
    
    // CompletableFuture<bool> removeSession();

    // CompletableFuture<bool> updateSession(HttpSession httpSession);

    bool isRequestedSessionIdFromURL()  { implementationMissing(false); return false; }

    bool isRequestedSessionIdFromCookie(){ implementationMissing(false); return false; }

    string getRequestedSessionId() { implementationMissing(false); return ""; }

    string getSessionIdParameterName() { implementationMissing(false); return ""; }

    // Template API
    // void renderTemplate(string resourceName, Object scope);

    // void renderTemplate(string resourceName, Object[] scopes);

    // void renderTemplate(string resourceName, List!Object scopes);

    // void renderTemplate(string resourceName) {
    //     renderTemplate(resourceName, Collections.emptyList());
    // }

}
