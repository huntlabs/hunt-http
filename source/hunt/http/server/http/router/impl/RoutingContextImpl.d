module hunt.http.server.http.router.impl.RoutingContextImpl;

import hunt.http.server.http.router.handler.HTTPBodyHandler;
import hunt.http.server.http.router.handler.HTTPSessionHandler;

import hunt.http.server.http.SimpleRequest;
import hunt.http.server.http.SimpleResponse;
import hunt.http.server.http.router.HTTPSession;
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
    private Array!(RouterMatchResult) routers;
    private  RouterMatchResult current;
    private  HTTPBodyHandlerSPI httpBodyHandlerSPI;
    private  HTTPSessionHandlerSPI httpSessionHandlerSPI;
    // private TemplateHandlerSPI templateHandlerSPI = TemplateHandlerSPILoader.getInstance().getTemplateHandlerSPI();
    private  bool asynchronousRead;
    // private  ConcurrentLinkedDeque<Promise<?>> handlerPromiseQueue;

    this(SimpleRequest request, Array!(RouterMatchResult) routers) {
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
        // current = routers.pollFirst();
        // return Optional.ofNullable(current)
        //                .map(RouterMatchResult::getRouter)
        //                .map(c -> (RouterImpl) c)
        //                .map(RouterImpl::getHandler)
        //                .map(handler -> {
        //                    handler.handle(this);
        //                    return true;
        //                })
        //                .orElse(false);
        implementationMissing();
        return false;
    }

    override
    bool hasNext() {
        return !routers.empty();
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
        //                .map(HTTPBodyHandlerSPI::getParameterMap)
        //                .orElse(Collections.emptyMap());
        if(httpBodyHandlerSPI is null)
            return null;
        else
            return httpBodyHandlerSPI.getParameterMap();
    }

    // override
    // Collection!Part getParts() {
    //     // return Optional.ofNullable(httpBodyHandlerSPI)
    //     //                .map(HTTPBodyHandlerSPI::getParts)
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
    //                    .map(HTTPBodyHandlerSPI::getInputStream)
    //                    .orElse(null);
    // }

    // override
    // BufferedReader getBufferedReader() {
    //     return Optional.ofNullable(httpBodyHandlerSPI)
    //                    .map(HTTPBodyHandlerSPI::getBufferedReader)
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
        //                .map(HTTPBodyHandlerSPI::getStringBody)
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
    //                    .map(HTTPBodyHandlerSPI::getJsonObjectBody)
    //                    .orElseGet(request::getJsonObjectBody);
    // }

    // override
    // JsonArray getJsonArrayBody() {
    //     return Optional.ofNullable(httpBodyHandlerSPI)
    //                    .map(HTTPBodyHandlerSPI::getJsonArrayBody)
    //                    .orElseGet(request::getJsonArrayBody);
    // }
    
    // void setHTTPBodyHandlerSPI(HTTPBodyHandlerSPI httpBodyHandlerSPI) {
    //     this.httpBodyHandlerSPI = httpBodyHandlerSPI;
    // }

    // override
    // CompletableFuture<HTTPSession> getSessionById(string id) {
    //     return Optional.ofNullable(httpSessionHandlerSPI).map(s -> s.getSessionById(id)).orElse(null);
    // }

    // override
    // CompletableFuture<HTTPSession> getSession() {
    //     return Optional.ofNullable(httpSessionHandlerSPI).map(HTTPSessionHandlerSPI::getSession).orElse(null);
    // }

    // override
    // CompletableFuture<HTTPSession> getSession(bool create) {
    //     return Optional.ofNullable(httpSessionHandlerSPI).map(s -> s.getSession(create)).orElse(null);
    // }

    // override
    // CompletableFuture<HTTPSession> getAndCreateSession(int maxAge) {
    //     return Optional.ofNullable(httpSessionHandlerSPI).map(s -> s.getAndCreateSession(maxAge)).orElse(null);
    // }

    // override
    // CompletableFuture<Integer> getSessionSize() {
    //     return Optional.ofNullable(httpSessionHandlerSPI).map(HTTPSessionHandlerSPI::getSessionSize).orElse(null);
    // }

    // override
    // CompletableFuture<bool> removeSessionById(string id) {
    //     return Optional.ofNullable(httpSessionHandlerSPI).map(s -> s.removeSessionById(id)).orElse(null);
    // }

    // override
    // CompletableFuture<bool> removeSession() {
    //     return Optional.ofNullable(httpSessionHandlerSPI)
    //                    .map(HTTPSessionHandlerSPI::removeSession)
    //                    .orElse(null);
    // }

    // override
    // CompletableFuture<bool> updateSession(HTTPSession httpSession) {
    //     return Optional.ofNullable(httpSessionHandlerSPI)
    //                    .map(s -> s.updateSession(httpSession))
    //                    .orElse(null);
    // }

    // override
    // bool isRequestedSessionIdFromURL() {
    //     return Optional.ofNullable(httpSessionHandlerSPI)
    //                    .map(HTTPSessionHandlerSPI::isRequestedSessionIdFromURL)
    //                    .orElse(false);
    // }

    // override
    // bool isRequestedSessionIdFromCookie() {
    //     return Optional.ofNullable(httpSessionHandlerSPI)
    //                    .map(HTTPSessionHandlerSPI::isRequestedSessionIdFromCookie)
    //                    .orElse(false);
    // }

    // override
    // string getRequestedSessionId() {
    //     return Optional.ofNullable(httpSessionHandlerSPI)
    //                    .map(HTTPSessionHandlerSPI::getRequestedSessionId)
    //                    .orElse(null);
    // }

    // override
    // string getSessionIdParameterName() {
    //     return Optional.ofNullable(httpSessionHandlerSPI)
    //                    .map(HTTPSessionHandlerSPI::getSessionIdParameterName)
    //                    .orElse(null);
    // }

    // void setHTTPSessionHandlerSPI(HTTPSessionHandlerSPI httpSessionHandlerSPI) {
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
