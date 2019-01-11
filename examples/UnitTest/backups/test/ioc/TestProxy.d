module test.ioc;

import hunt.http.core.ApplicationContext;
import hunt.http.core.XmlApplicationContext;
import hunt.Assert;
import hunt.util.Test;
import test.proxy.NameService;



/**
 * 
 */
public class TestProxy {

    public static ApplicationContext ctx = new XmlApplicationContext("aop-test.xml");

    
    public void test() {
        NameService nameService = ctx.getBean(NameService.class);
        string name = nameService.getName("hello");
        writeln(name);
        Assert.assertThat(name, is("name: (p2,(p1,(female->p3,(p4->fuck you(female->p3,(p2,(p1,hello,p1),p2),p3),p4->fuck you),p3),p1),p2)"));
    }
}
