module test.proxy;

import hunt.http.annotation.Component;
import hunt.http.utils.ReflectUtils;
import hunt.http.utils.classproxy.ClassProxy;

/**
 * 
 */
@Component("nameServiceProxy1")
public class NameServiceProxy1 : ClassProxy {
    override
    public Object intercept(ReflectUtils.MethodProxy handler, Object originalInstance, Object[] args) {
        string id = (string) args[0];
        writeln("enter proxy1, id: " ~ id);
        return handler.invoke(originalInstance, "(p1," ~ id ~ ",p1)");
    }
}
