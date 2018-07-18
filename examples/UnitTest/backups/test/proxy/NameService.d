module test.proxy;

import hunt.http.annotation.Component;
import hunt.http.annotation.Proxy;

/**
 * 
 */
@Proxy(proxyClass = NameServiceProxy2.class)
@Proxy(proxyClass = NameServiceProxy1.class)
@Proxy(proxyClass = NameServiceProxy3.class)
@NameProxy
@Component
public class NameService {
    public string getName(string id) {
        return "name: " ~ id;
    }
}
