module hunt.http.AuthenticationScheme;

/** 
 * 
 * 
 * See_Also: 
 *  https://developer.mozilla.org/en-US/docs/Web/HTTP/Authentication
 */
enum AuthenticationScheme : string {
    None = "None",
    Basic = "Basic",
    Bearer = "Bearer",
    Digest = "Digest",
    HOBA = "HOBA",
    Mutual = "Mutual"
}