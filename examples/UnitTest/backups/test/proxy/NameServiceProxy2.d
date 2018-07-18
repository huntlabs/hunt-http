module test.proxy;

import hunt.http.annotation.Component;
import hunt.http.utils.ReflectUtils;
import hunt.http.utils.classproxy.ClassProxy;

/**
 * 
 */
@Component("nameServiceProxy2")
public class NameServiceProxy2 : ClassProxy {
    override
    public Object intercept(ReflectUtils.MethodProxy handler, Object originalInstance, Object[] args) {
        string id = (string) args[0];
        writeln("enter proxy2, id: " ~ id);
        return handler.invoke(originalInstance, "(p2," ~ id ~ ",p2)");
    }
}
