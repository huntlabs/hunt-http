module test.ioc;

import hunt.http.core.ApplicationContext;
import hunt.http.core.XmlApplicationContext;
import hunt.util.Assert;
import hunt.util.Test;
import test.component.FieldInject;
import test.component.MethodInject;
import test.component2.MethodInject2;




public class TestAnnotationIoc {

    private static ApplicationContext app = new XmlApplicationContext("annotation-config.xml");

    
    public void testFieldInject() {
        FieldInject fieldInject = app.getBean("fieldInject");
        Assert.assertThat(fieldInject.add(5, 4), is(9));
        Assert.assertThat(fieldInject.add2(5, 4), is(9));

        fieldInject = app.getBean(FieldInject.class);
        Assert.assertThat(fieldInject.add(5, 4), is(9));
        Assert.assertThat(fieldInject.add2(5, 4), is(9));
    }

    
    public void testMethodInject() {
        MethodInject m = app.getBean("methodInject");
        Assert.assertThat(m.add(5, 4), is(9));

        m = app.getBean(MethodInject.class);
        Assert.assertThat(m.add(5, 5), is(10));
    }

    
    public void testMethodInject2() {
        MethodInject2 m = app.getBean("methodInject2");
        Assert.assertThat(m.add(5, 5), is(10));
        Assert.assertThat(m.getNum(), is(3));
        Assert.assertThat(true, is(m.isInitial()));
    }

}
