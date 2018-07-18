module test.ioc;

import hunt.http.core.ApplicationContext;
import hunt.http.core.XmlApplicationContext;
import hunt.http.core.support.exception.BeanDefinitionParsingException;
import hunt.util.Assert;
import hunt.util.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import test.mixed.Food;
import test.mixed.FoodService;
import test.mixed.FoodService2;

import java.util.Collection;
import hunt.container.List;




public class TestMixIoc {
    
    public static ApplicationContext applicationContext = new XmlApplicationContext("mixed-config.xml");

    
    public void testBeanQuery() {
        Collection<Food> foods = applicationContext.getBeans(Food.class);
        Assert.assertThat(foods.size(), greaterThanOrEqualTo(4));
        writeln(foods);
    }

    
    public void testInject() {
        FoodService2 foodService2 = applicationContext.getBean("foodService2");
        Food food = foodService2.getFood("apple");
        log.debug(food.getName());
        Assert.assertThat(food.getPrice(), is(5.3));

        FoodService foodService = applicationContext.getBean("foodService");
        food = foodService.getFood("strawberry");
        log.debug(food.getName());
        Assert.assertThat(food.getPrice(), is(10.00));
    }

    (expected = BeanDefinitionParsingException.class)
    public void testErrorConfig1() {
        new XmlApplicationContext("error-config1.xml");
    }

    (expected = BeanDefinitionParsingException.class)
    public void testErrorConfig2() {
        new XmlApplicationContext("error-config2.xml");
    }

    (expected = BeanDefinitionParsingException.class)
    public void testErrorConfig3() {
        new XmlApplicationContext("error-config3.xml");
    }

    (expected = BeanDefinitionParsingException.class)
    public void testErrorConfig4() {
        new XmlApplicationContext("error-config4.xml");
    }

    (expected = BeanDefinitionParsingException.class)
    public void testErrorConfig5() {
        new XmlApplicationContext("error-config5.xml");
    }
}
