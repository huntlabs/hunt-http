module test.proxy;

import hunt.http.annotation.Proxy;

import java.lang.annotation;

/**
 * 
 */
@Target( { ElementType.TYPE })
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Proxy(proxyClass = NameServiceProxy4.class)
@Proxy(proxyClass = NameServiceProxy3.class)
@Proxy(proxyClass = NameServiceProxy2.class)
@Proxy(proxyClass = NameServiceProxy1.class)
public @interface NameProxy {
}
