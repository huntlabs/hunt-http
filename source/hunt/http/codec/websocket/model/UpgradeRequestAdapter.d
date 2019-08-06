module hunt.http.codec.websocket.model.UpgradeRequestAdapter;

import hunt.http.codec.http.model.Cookie;
import hunt.net.util.HttpURI;
import hunt.text.QuoteUtil;

// dfmt off
version(WITH_HUNT_SECURITY) {
    import hunt.security.Principal;
}
// dfmt on

import hunt.http.codec.websocket.utils.HeaderValueGenerator;

// class UpgradeRequestAdapter : UpgradeRequest {
//     private HttpURI requestURI;
//     private List<string> subProtocols = new ArrayList<>(1);
//     private List<ExtensionConfig> extensions = new ArrayList<>(1);
//     private List<Cookie> cookies = new ArrayList<>(1);
//     private Map<string, List<string>> headers = new TreeMap<>(string.CASE_INSENSITIVE_ORDER);
//     private Map<string, List<string>> parameters = new HashMap<>(1);
//     private Object session;
//     private string httpVersion;
//     private string method;
//     private string host;
//     private bool secure;

//     protected this() {
//         /* anonymous, no requestURI, upgrade request */
//     }

//     this(string requestURI) {
//         this(new HttpURI(requestURI));
//     }

//     this(HttpURI requestURI) {
//         setRequestURI(requestURI);
//     }

//     override
//     void addExtensions(ExtensionConfig[] configs...) {
//         Collections.addAll(extensions, configs);
//     }

//     override
//     void addExtensions(string[] configs...) {
//         foreach (string config ; configs) {
//             extensions.add(ExtensionConfig.parse(config));
//         }
//     }

//     override
//     List<Cookie> getCookies() {
//         return cookies;
//     }

//     override
//     List<ExtensionConfig> getExtensions() {
//         return extensions;
//     }

//     override
//     string getHeader(string name) {
//         List<string> values = headers.get(name);
//         // no value list
//         if (values is null) {
//             return null;
//         }
//         int size = values.size();
//         // empty value list
//         if (size <= 0) {
//             return null;
//         }
//         // simple return
//         if (size == 1) {
//             return values.get(0);
//         }
//         return generateHeaderValue(values);
//     }

//     override
//     int getHeaderInt(string name) {
//         List<string> values = headers.get(name);
//         // no value list
//         if (values is null) {
//             return -1;
//         }
//         int size = values.size();
//         // empty value list
//         if (size <= 0) {
//             return -1;
//         }
//         // simple return
//         if (size == 1) {
//             return Integer.parseInt(values.get(0));
//         }
//         throw new NumberFormatException("Cannot convert multi-value header into int");
//     }

//     override
//     Map<string, List<string>> getHeaders() {
//         return headers;
//     }

//     override
//     List<string> getHeaders(string name) {
//         return headers.get(name);
//     }

//     override
//     string getHost() {
//         return host;
//     }

//     override
//     string getHttpVersion() {
//         return httpVersion;
//     }

//     override
//     string getMethod() {
//         return method;
//     }

//     override
//     string getOrigin() {
//         return getHeader("Origin");
//     }

//     /**
//      * Returns a map of the query parameters of the request.
//      *
//      * @return a unmodifiable map of query parameters of the request.
//      */
//     override
//     Map<string, List<string>> getParameterMap() {
//         return Collections.unmodifiableMap(parameters);
//     }

//     override
//     string getProtocolVersion() {
//         string version = getHeader("Sec-WebSocket-Version");
//         if (version is null) {
//             return "13"; // Default
//         }
//         return version;
//     }

//     override
//     string getQueryString() {
//         return requestURI.getQuery();
//     }

//     override
//     HttpURI getRequestURI() {
//         return requestURI;
//     }

//     /**
//      * Access the Servlet HTTP Session (if present)
//      * <p>
//      * Note: Never present on a Client UpgradeRequest.
//      *
//      * @return the Servlet HttpSession on server side UpgradeRequests
//      */
//     override
//     Object getSession() {
//         return session;
//     }

//     override
//     List<string> getSubProtocols() {
//         return subProtocols;
//     }

//     /**
//      * Get the User Principal for this request.
//      * <p>
//      * Only applicable when using UpgradeRequest from server side.
//      *
//      * @return the user principal
//      */
//     override
//     Principal getUserPrincipal() {
//         // Server side should override to implement
//         return null;
//     }

//     override
//     bool hasSubProtocol(string test) {
//         for (string protocol : subProtocols) {
//             if (protocol.equalsIgnoreCase(test)) {
//                 return true;
//             }
//         }
//         return false;
//     }

//     override
//     bool isOrigin(string test) {
//         return test.equalsIgnoreCase(getOrigin());
//     }

//     override
//     bool isSecure() {
//         return secure;
//     }

//     override
//     void setCookies(List<Cookie> cookies) {
//         this.cookies.clear();
//         if (cookies !is null && !cookies.isEmpty()) {
//             this.cookies.addAll(cookies);
//         }
//     }

//     override
//     void setExtensions(List<ExtensionConfig> configs) {
//         this.extensions.clear();
//         if (configs !is null) {
//             this.extensions.addAll(configs);
//         }
//     }

//     override
//     void setHeader(string name, List<string> values) {
//         headers.put(name, values);
//     }

//     override
//     void setHeader(string name, string value) {
//         List<string> values = new ArrayList<>();
//         values.add(value);
//         setHeader(name, values);
//     }

//     override
//     void setHeaders(Map<string, List<string>> headers) {
//         headers.clear();

//         for (Map.Entry<string, List<string>> entry : headers.entrySet()) {
//             string name = entry.getKey();
//             List<string> values = entry.getValue();
//             setHeader(name, values);
//         }
//     }

//     override
//     void setHttpVersion(string httpVersion) {
//         this.httpVersion = httpVersion;
//     }

//     override
//     void setMethod(string method) {
//         this.method = method;
//     }

//     protected void setParameterMap(Map<string, List<string>> parameters) {
//         this.parameters.clear();
//         this.parameters.putAll(parameters);
//     }

//     override
//     void setRequestURI(HttpURI uri) {
//         this.requestURI = uri;
//         string scheme = uri.getScheme();
//         if ("ws".equalsIgnoreCase(scheme)) {
//             secure = false;
//         } else if ("wss".equalsIgnoreCase(scheme)) {
//             secure = true;
//         } else {
//             throw new IllegalArgumentException("URI scheme must be 'ws' or 'wss'");
//         }
//         this.host = this.requestURI.getHost();
//         this.parameters.clear();
//     }

//     override
//     void setSession(Object session) {
//         this.session = session;
//     }

//     override
//     void setSubProtocols(List<string> subProtocols) {
//         this.subProtocols.clear();
//         if (subProtocols !is null) {
//             this.subProtocols.addAll(subProtocols);
//         }
//     }

//     /**
//      * Set Sub Protocol request list.
//      *
//      * @param protocols the sub protocols desired
//      */
//     override
//     void setSubProtocols(string... protocols) {
//         subProtocols.clear();
//         Collections.addAll(subProtocols, protocols);
//     }
// }
