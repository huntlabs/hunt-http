module hunt.http.server.http.router.impl.RoutingContextImpl;

import hunt.http.server.http.router.handler;
import hunt.http.server.http.router.impl.RouterImpl;

import hunt.http.server.http.SimpleRequest;
import hunt.http.server.http.SimpleResponse;
import hunt.http.server.http.router.HttpSession;
import hunt.http.server.http.router.RouterManager;
import hunt.http.server.http.router.RoutingContext;

import hunt.util.concurrent.Promise;
import hunt.util.exception;
import hunt.util.functional;

import hunt.container;

import std.container;

/**
 * 
 */
class RoutingContextImpl : RoutingContext {

    private SimpleRequest request;
    private NavigableSet!(RouterMatchResult) routers;
    private  RouterMatchResult current;
    private  HttpBodyHandlerSPI httpBodyHandlerSPI;
    private  HttpSessionHandlerSPI httpSessionHandlerSPI;
    // private TemplateHandlerSPI templateHandlerSPI = TemplateHandlerSPILoader.getInstance().getTemplateHandlerSPI();
    private  bool asynchronousRead;
    // private  ConcurrentLinkedDeque<Promise<?>> handlerPromiseQueue;

    this(SimpleRequest request, NavigableSet!(RouterMatchResult) routers) {
        this.request = request;
        this.routers = routers;
    }

    override
    string getAttribute(string key) {
        return request.get(key);
    }

    override
    string setAttribute(string key, string value) {
        return request.put(key, value);
    }

    override
    string removeAttribute(string key) {
        return request.remove(key);
    }

    override
    string[string] getAttributes() {
        return request.getAttributes();
    }

    override
    SimpleResponse getResponse() {
        return request.getResponse();
    }

    override
    SimpleResponse getAsyncResponse() {
        return request.getAsyncResponse();
    }

    override
    SimpleRequest getRequest() {
        return request;
    }

    override
    string getRouterParameter(string name) {
        return current.getParameters().get(name);
    }

    override
    RoutingContext onContent(Action1!ByteBuffer c) {
        request.onContent(c);
        asynchronousRead = true;
        return this;
    }

    override
    RoutingContext onContentComplete(Action1!SimpleRequest contentComplete) {
        request.onContentComplete(contentComplete);
        asynchronousRead = true;
        return this;
    }

    override
    RoutingContext onMessageComplete(Action1!SimpleRequest messageComplete) {
        request.onMessageComplete(messageComplete);
        asynchronousRead = true;
        return this;
    }

    override
    bool isAsynchronousRead() {
        return asynchronousRead;
    }

    override
    bool next() {
        current = routers.pollFirst();
        if(current !is null) {
            RouterImpl r = cast(RouterImpl)current.getRouter();
            Handler handler = r.getHandler();
            handler.handle(this);
            return true;
        }
        return false;
    }

    override
    bool hasNext() {
        return !routers.isEmpty();
    }

    // override
    // <T> RoutingContext complete(Promise<T> promise) {
    //     ConcurrentLinkedDeque<Promise<T>> queue = createHandlerPromiseQueueIfAbsent();
    //     queue.push(promise);
    //     return this;
    // }

    // override
    // <T> bool next(Promise<T> promise) {
    //     return complete(promise).next();
    // }

    
    // override
    // <T> void succeed(T t) {
    //     Optional.ofNullable(handlerPromiseQueue)
    //             .map(ConcurrentLinkedDeque::pop)
    //             .map(p -> (Promise<T>) p)
    //             .ifPresent(p -> p.succeeded(t));
    // }

    // override
    // void fail(Throwable x) {
    //     Optional.ofNullable(handlerPromiseQueue)
    //             .map(ConcurrentLinkedDeque::pop)
    //             .ifPresent(p -> p.failed(x));
    // }

    
    // private <T> ConcurrentLinkedDeque<Promise<T>> createHandlerPromiseQueueIfAbsent() {
    //     if (handlerPromiseQueue == null) {
    //         handlerPromiseQueue = new ConcurrentLinkedDeque<>();
    //     }
    //     return (ConcurrentLinkedDeque) handlerPromiseQueue;
    // }

    // override
    void close() {
        request.getResponse().close();
    }

    override
    string getParameter(string name) {
        // return Optional.ofNullable(httpBodyHandlerSPI)
        //                .map(s -> s.getParameter(name))
        //                .orElse(null);
        if(httpBodyHandlerSPI is null)
            return null;
        else
        {
            return httpBodyHandlerSPI.getParameter(name);
        }
    }

    override
    List!string getParameterValues(string name) {
        // return Optional.ofNullable(httpBodyHandlerSPI)
        //                .map(s -> s.getParameterValues(name))
        //                .orElse(Collections.emptyList());
        if(httpBodyHandlerSPI is null)
            return new EmptyList!string(); // Collections.emptyList!string();
        else
            return httpBodyHandlerSPI.getParameterValues(name);
    }

    override
    Map!(string, List!string) getParameterMap() {
        // return Optional.ofNullable(httpBodyHandlerSPI)
        //                .map(HttpBodyHandlerSPI::getParameterMap)
        //                .orElse(Collections.emptyMap());
        if(httpBodyHandlerSPI is null)
            return null;
        else
            return httpBodyHandlerSPI.getParameterMap();
    }

    // override
    // Collection!Part getParts() {
    //     // return Optional.ofNullable(httpBodyHandlerSPI)
    //     //                .map(HttpBodyHandlerSPI::getParts)
    //     //                .orElse(Collections.emptyList());
    //     if(httpBodyHandlerSPI is null)
    //         return null;
    //     else
    //         return httpBodyHandlerSPI.getParts();
    // }

    // override
    // Part getPart(string name) {
    //     // return Optional.ofNullable(httpBodyHandlerSPI)
    //     //                .map(s -> s.getPart(name))
    //     //                .orElse(null);
    //     if(httpBodyHandlerSPI is null)
    //         return null;
    //     else
    //         return httpBodyHandlerSPI.getPart(name);
    // }

    // override
    // InputStream getInputStream() {
    //     return Optional.ofNullable(httpBodyHandlerSPI)
    //                    .map(HttpBodyHandlerSPI::getInputStream)
    //                    .orElse(null);
    // }

    // override
    // BufferedReader getBufferedReader() {
    //     return Optional.ofNullable(httpBodyHandlerSPI)
    //                    .map(HttpBodyHandlerSPI::getBufferedReader)
    //                    .orElse(null);
    // }

    override
    string getStringBody(string charset) {
        // return Optional.ofNullable(httpBodyHandlerSPI)
        //                .map(s -> s.getStringBody(charset))
        //                .orElseGet(() -> request.getStringBody(charset));
        if(httpBodyHandlerSPI is null)
            return request.getStringBody(charset);
        else
            return httpBodyHandlerSPI.getStringBody(charset);
    }

    override
    string getStringBody() {
        // return Optional.ofNullable(httpBodyHandlerSPI)
        //                .map(HttpBodyHandlerSPI::getStringBody)
        //                .orElseGet(request::getStringBody);
        if(httpBodyHandlerSPI is null)
            return request.getStringBody();
        else
            return httpBodyHandlerSPI.getStringBody();
    }

    // override
    // <T> T getJsonBody(Class<T> clazz) {
    //     return Optional.ofNullable(httpBodyHandlerSPI)
    //                    .map(s -> s.getJsonBody(clazz))
    //                    .orElseGet(() -> request.getJsonBody(clazz));
    // }

    // override
    // <T> T getJsonBody(GenericTypeReference<T> typeReference) {
    //     return Optional.ofNullable(httpBodyHandlerSPI)
    //                    .map(s -> s.getJsonBody(typeReference))
    //                    .orElseGet(() -> request.getJsonBody(typeReference));

    // }

    // override
    // JsonObject getJsonObjectBody() {
    //     return Optional.ofNullable(httpBodyHandlerSPI)
    //                    .map(HttpBodyHandlerSPI::getJsonObjectBody)
    //                    .orElseGet(request::getJsonObjectBody);
    // }

    // override
    // JsonArray getJsonArrayBody() {
    //     return Optional.ofNullable(httpBodyHandlerSPI)
    //                    .map(HttpBodyHandlerSPI::getJsonArrayBody)
    //                    .orElseGet(request::getJsonArrayBody);
    // }
    
    void setHttpBodyHandlerSPI(HttpBodyHandlerSPI httpBodyHandlerSPI) {
        this.httpBodyHandlerSPI = httpBodyHandlerSPI;
    }

    // override
    // CompletableFuture<HttpSession> getSessionById(string id) {
    //     return Optional.ofNullable(httpSessionHandlerSPI).map(s -> s.getSessionById(id)).orElse(null);
    // }

    // override
    // CompletableFuture<HttpSession> getSession() {
    //     return Optional.ofNullable(httpSessionHandlerSPI).map(HttpSessionHandlerSPI::getSession).orElse(null);
    // }

    // override
    // CompletableFuture<HttpSession> getSession(bool create) {
    //     return Optional.ofNullable(httpSessionHandlerSPI).map(s -> s.getSession(create)).orElse(null);
    // }

    // override
    // CompletableFuture<HttpSession> getAndCreateSession(int maxAge) {
    //     return Optional.ofNullable(httpSessionHandlerSPI).map(s -> s.getAndCreateSession(maxAge)).orElse(null);
    // }

    // override
    // CompletableFuture<Integer> getSessionSize() {
    //     return Optional.ofNullable(httpSessionHandlerSPI).map(HttpSessionHandlerSPI::getSessionSize).orElse(null);
    // }

    // override
    // CompletableFuture<bool> removeSessionById(string id) {
    //     return Optional.ofNullable(httpSessionHandlerSPI).map(s -> s.removeSessionById(id)).orElse(null);
    // }

    // override
    // CompletableFuture<bool> removeSession() {
    //     return Optional.ofNullable(httpSessionHandlerSPI)
    //                    .map(HttpSessionHandlerSPI::removeSession)
    //                    .orElse(null);
    // }

    // override
    // CompletableFuture<bool> updateSession(HttpSession httpSession) {
    //     return Optional.ofNullable(httpSessionHandlerSPI)
    //                    .map(s -> s.updateSession(httpSession))
    //                    .orElse(null);
    // }

    // override
    // bool isRequestedSessionIdFromURL() {
    //     return Optional.ofNullable(httpSessionHandlerSPI)
    //                    .map(HttpSessionHandlerSPI::isRequestedSessionIdFromURL)
    //                    .orElse(false);
    // }

    // override
    // bool isRequestedSessionIdFromCookie() {
    //     return Optional.ofNullable(httpSessionHandlerSPI)
    //                    .map(HttpSessionHandlerSPI::isRequestedSessionIdFromCookie)
    //                    .orElse(false);
    // }

    // override
    // string getRequestedSessionId() {
    //     return Optional.ofNullable(httpSessionHandlerSPI)
    //                    .map(HttpSessionHandlerSPI::getRequestedSessionId)
    //                    .orElse(null);
    // }

    // override
    // string getSessionIdParameterName() {
    //     return Optional.ofNullable(httpSessionHandlerSPI)
    //                    .map(HttpSessionHandlerSPI::getSessionIdParameterName)
    //                    .orElse(null);
    // }

    // void setHttpSessionHandlerSPI(HttpSessionHandlerSPI httpSessionHandlerSPI) {
    //     this.httpSessionHandlerSPI = httpSessionHandlerSPI;
    // }

    // override
    // void renderTemplate(string resourceName, Object scope) {
    //     templateHandlerSPI.renderTemplate(this, resourceName, scope);
    // }

    // override
    // void renderTemplate(string resourceName, Object[] scopes) {
    //     templateHandlerSPI.renderTemplate(this, resourceName, scopes);
    // }

    // override
    // void renderTemplate(string resourceName, List<Object> scopes) {
    //     templateHandlerSPI.renderTemplate(this, resourceName, scopes);
    // }
}
