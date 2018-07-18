module test.proxy;

import hunt.http.annotation.DestroyedMethod;
import hunt.http.annotation.InitialMethod;
import hunt.http.annotation.Inject;
import hunt.http.utils.ReflectUtils;
import hunt.http.utils.classproxy.ClassProxy;

/**
 * 
 */
public class NameServiceProxy4 : ClassProxy {

    @Inject
    private FuckService fuckService;

    override
    public Object intercept(ReflectUtils.MethodProxy handler, Object originalInstance, Object[] args) {
        string id = (string) args[0];
        writeln("enter proxy4, id: " ~ id);
        return handler.invoke(originalInstance, "(p4->" ~ fuckService.fuck() + id ~ ",p4->" ~ fuckService.fuck() ~ ")");
    }

    @InitialMethod
    public void init() {
        writeln("init proxy 4 -> " ~ fuckService.fuck());
    }

    @DestroyedMethod
    public void destroy() {
        writeln("destroy proxy 4 -> " ~ fuckService.fuck());
    }
}
