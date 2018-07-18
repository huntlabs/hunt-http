module test.proxy;

import hunt.http.annotation.Component;
import hunt.http.annotation.Inject;
import hunt.http.utils.ReflectUtils;
import hunt.http.utils.classproxy.ClassProxy;

/**
 * 
 */
@Component("nameServiceProxy3")
public class NameServiceProxy3 : ClassProxy {

    @Inject
    private SexService sexService;

    override
    public Object intercept(ReflectUtils.MethodProxy handler, Object originalInstance, Object[] args) {
        string id = (string) args[0];
        writeln("enter proxy3, id: " ~ id);
        return handler.invoke(originalInstance, "(" ~ sexService.getSex() ~ "->p3," ~ id ~ ",p3)");
    }
}
