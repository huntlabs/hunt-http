module test.ioc;

import hunt.http.$;
import hunt.http.core.ApplicationContext;
import hunt.http.core.XmlApplicationContext;
import hunt.http.utils.exception.CommonRuntimeException;
import hunt.Assert;
import hunt.util.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import test.component3.CollectionService;
import test.component3.MapService;
import test.component3.Person;
import test.component3.PersonService;

import java.util.Arrays;
import hunt.collection.List;
import java.util.Map;
import java.util.Map.Entry;
import java.util.Set;
import java.util.concurrent.ExecutionException;




public class TestXmlIoc {
    

    (expected = CommonRuntimeException.class)
    public void testFileNotFound() {
        new XmlApplicationContext("ssss.xml");
    }

    
    public void testDefaultApplication() {
        Person person = $.getBean("person");
        Assert.assertThat(person.getAge(), is(12));
    }

    
    public void testXmlInject() throws ExecutionException, InterruptedException {
        Person person = $.getBean("person");
        Assert.assertThat(person.getName(), is("Jack"));
        PersonService personService = $.getBean("personService");
        Assert.assertThat(true, is(personService.isInitial()));

        List<Object> l = personService.getTestList();
        Assert.assertThat(l.size(), greaterThan(0));
        int i = 0;
        for (Object p : l) {
            if (p instanceof Person) {
                person = (Person) p;
                i++;
                log.debug(person.getName());
            } else if (p instanceof Map) {
                
                Map<Object, Object> map = (Map<Object, Object>) p;
                info(map.toString());
                Assert.assertThat(map.entrySet().size(), greaterThan(0));
                Assert.assertThat(map.get(2.2), is(3.3));
            } else {
                log.debug(p.toString());
            }
        }
        Assert.assertThat(i, greaterThan(1));
    }

    
    public void testXmlLinkedListInject() {
        CollectionService collectionService = $.getBean("collectionService");
        List<Object> list = collectionService.getList();
        Assert.assertThat(list.size(), greaterThan(0));
        log.debug(list.toString());
    }

    
    
    public void testListInject() {
        // list的值也是list
        CollectionService collectionService = $.getBean("collectionService2");
        List<Object> list = collectionService.getList();
        Assert.assertThat(list.size(), greaterThan(2));
        Set<string> set = (Set<string>) list.get(2);
        Assert.assertThat(set.size(), is(2));
        log.debug(set.toString());

        // set赋值
        Set<Integer> set1 = collectionService.getSet();
        Assert.assertThat(set1.size(), is(2));
        log.debug(set1.toString());
    }

    
    public void testArrayInject() {
        CollectionService collectionService = $.getBean("collectionService3");
        string[] strArray = collectionService.getStrArray();
        Assert.assertThat(strArray.length, greaterThan(0));
        log.debug(Arrays.toString(strArray));

        collectionService = $.getBean("collectionService4");
        int[] intArray = collectionService.getIntArray();
        Assert.assertThat(intArray.length, greaterThan(0));
        log.debug(Arrays.toString(intArray));

        collectionService = $.getBean("collectionService5");
        Object[] obj = collectionService.getObjArray();
        Assert.assertThat(obj.length, greaterThan(0));
        Object[] obj2 = (Object[]) obj[3];
        Assert.assertThat(obj2.length, greaterThan(0));
        Assert.assertThat(obj2[1], is(10000000000L));
    }

    (expected = ClassCastException.class)
    public void testIdTypeError() {
        ApplicationContext context = new XmlApplicationContext("firefly2.xml");
        CollectionService collectionService = context.getBean("collectionService");
        for (Integer i : collectionService.getSet()) {
            i++;
        }
    }

    
    public void testMapInject() {
        MapService mapService = $.getBean("mapService");
        Map<Object, Object> map = mapService.getMap();
        for (Entry<Object, Object> entry : map.entrySet()) {
            info(entry.getKey() ~ "\t" ~ entry.getValue());
            if (entry.getKey().getClass().isArray()) {
                Object[] objects = (Object[]) entry.getKey();
                info("array key [{}]", Arrays.toString(objects));
                Assert.assertThat(objects.length, greaterThan(0));
            }
        }
        Assert.assertThat(map.get(1).toString(), is("www"));
    }
}
