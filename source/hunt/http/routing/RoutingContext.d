module hunt.http.routing.RoutingContext;

import hunt.http.server.HttpSession;
import hunt.http.server.HttpServerRequest;
import hunt.http.server.HttpServerResponse;

import hunt.http.codec.http.model;
import hunt.http.HttpOutputStream;
import hunt.http.routing.handler;

import hunt.http.Cookie;
import hunt.http.HttpHeader;
import hunt.http.HttpFields;
import hunt.http.HttpStatus;
import hunt.http.HttpVersion;

import hunt.concurrency.Promise;
import hunt.Exceptions;
import hunt.Functions;
import hunt.io.Common;
import hunt.logging.ConsoleLogger;
import hunt.util.Common;
import hunt.net.util.HttpURI;

import hunt.collection.ByteBuffer;
import hunt.collection.List;
import hunt.collection.Map;

import std.conv;
import std.variant;

alias RoutingHandler =  void delegate(RoutingContext routingContext);

deprecated("Using RouteHandler instead.")
alias Handler = RouteHandler;

/**
 * 
 */
interface RouteHandler {
    void handle(RoutingContext context);
}


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
    
    final T getAttributeAs(T)(string key) {
        return getAttribute(key).get!T();
    }

    final void setAttribute(T)(string key, T value) if(!is(T == Variant)) {
        setAttribute(key, value.Variant());
    }

    Variant getAttribute(string key);

    void setAttribute(string key, Variant value);

    Variant removeAttribute(string key);

    Variant[string] getAttributes();

    HttpServerResponse getResponse();

    void response(HttpServerResponse response);

    // HttpResponse getAsyncResponse();

    HttpServerRequest getRequest();

    // HttpOutputStream getOutputStream();  
    OutputStream outputStream(); 

    int getConnectionId();

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
    // RoutingContext onContent(Action1!ByteBuffer content);

    /**
     * Set the HTTP body packet complete callback.
     *
     * @param contentComplete The HTTP body packet complete callback.
     * @return RoutingContext
     */
    // RoutingContext onContentComplete(Action1!(HttpRequest) contentComplete);

    /**
     * Set the HTTP message complete callback.
     *
     * @param messageComplete the HTTP message complete callback.
     * @return RoutingContext
     */
    // RoutingContext onMessageComplete(Action1!(HttpRequest) messageComplete);

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
    void next();

    /**
     * If return false, it represents current handler is the last.
     *
     * @return If return false, it represents current handler is the last.
     */
    bool hasNext();

    // <T> RoutingContext complete(Promise<T> promise);

    // <T> bool next(Promise<T> promise);

    // <T> T> nextFuture() {
    //     Promise.Completable<T> completable = new Promise.Completable<>();
    //     next(completable);
    //     return completable;
    // }

    // <T> T> complete() {
    //     Promise.Completable<T> completable = new Promise.Completable<>();
    //     complete(completable);
    //     return completable;
    // }

    
    void succeed(bool t) { 
        version(HUNT_HTTP_DEBUG) trace("do nothing");
    }

    void fail(Exception ex) { 
        // version(HUNT_DEBUG) warning(ex);
        // if(!isCommitted()) {
        //     HttpServerResponse res = getResponse();
        //     if(res !is null) {
        //         res.setStatus(HttpStatus.BAD_REQUEST_400);
        //     }
        //     end(ex.msg);
        // }
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

    Cookie[] getCookies() {
        return getRequest().getCookies();
    }

    string getParameter(string name);

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

    void responseHeader(HttpHeader header, HttpHeaderValue value) {
        getResponse().getFields().put(header, value);
    }

    void responseHeader(string header, string value) {
        getResponse().getFields().put(header, value);
    }

    void responseHeader(HttpHeader header, string value) {
        getResponse().getFields().put(header, value);
    }

    RoutingContext addCookie(Cookie cookie) {
        getResponse().addCookie(cookie);
        return this;
    }

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


    // HTTP session API
    HttpSession getSessionById(string id);

    HttpSession getSession();

    HttpSession getSession(bool create);

    HttpSession getAndCreateSession(int maxAge);

    int getSessionSize();

    bool removeSessionById(string id);
    
    bool removeSession();

    bool updateSession(HttpSession httpSession);

    bool isRequestedSessionIdFromURL();

    bool isRequestedSessionIdFromCookie();

    string getRequestedSessionId();

    string getSessionIdParameterName();

    string groupName();
    
    void groupName(string name);

    // Template API
    // void renderTemplate(string resourceName, Object scope);

    // void renderTemplate(string resourceName, Object[] scopes);

    // void renderTemplate(string resourceName, List!Object scopes);

    // void renderTemplate(string resourceName) {
    //     renderTemplate(resourceName, Collections.emptyList());
    // }

}
