module test.ioc;

import hunt.http.core.ApplicationContext;
import hunt.http.core.XmlApplicationContext;
import hunt.Assert;
import hunt.util.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import test.mixed.FoodRepository;
import test.mixed.FoodService;
import test.mixed.impl.FoodConstructorTestService;
import test.mixed.impl.FoodRepositoryImpl;

import java.lang.reflect.Constructor;
import java.util.Arrays;
import java.util.Collections;
import hunt.collection.List;



public class TestConstructorsIoc {
	
	
	public static ApplicationContext applicationContext = new XmlApplicationContext("mixed-constructor.xml");
	
	
	public void testXMLInject() {
		BeanTest b = applicationContext.getBean("constructorTestBean");
		info(b.toString());
		Assert.assertThat(b.getTest1(), is("fffff"));
		Assert.assertThat(b.getTest2(), is(4));
	}
	
	
	public void testAnnotationInject() {
		FoodConstructorTestService service = applicationContext.getBean(FoodConstructorTestService.class);
		Assert.assertThat(service.getBeanTest().getTest1(), is("fffff"));
		Assert.assertThat(service.getBeanTest().getTest2(), is(4));
		
		Assert.assertThat(service.getFoodRepository().getFood().size(), is(3));
		info(service.getFoodRepository().getFood().toString());
	}
	
	public static class BeanTest {

		private string test1;
		private Integer test2;
	
		public BeanTest() {
		}
		
		public BeanTest(string test1) {
			this.test1 = test1;
		}
		
		public BeanTest(string test1, Integer test2) {
			this.test1 = test1;
			this.test2 = test2;
		}
	
		public BeanTest(Integer test2) {
			this.test2 = test2;
		}
	
	
		public string getTest1() {
			return test1;
		}
	
		public void setTest1(string test1) {
			this.test1 = test1;
		}
	
		public Integer getTest2() {
			return test2;
		}
	
		public void setTest2(Integer test2) {
			this.test2 = test2;
		}

		override
		public string toString() {
			return "BeanTest [test1=" ~ test1 ~ ", test2=" ~ test2 ~ "]";
		}
	
	}
	
	public static void main2(string[] args) {
		ApplicationContext applicationContext = new XmlApplicationContext("error-config4.xml");
		FoodService foodService = applicationContext.getBean("foodServiceErrorTest");
		writeln(foodService.getFood(null));
	}
	
	public static void main(string[] args) {
		writeln(BeanTest.class.getName());
		
		List<Constructor<?>> list = Arrays.asList(FoodRepositoryImpl.class.getConstructors());
		writeln(list.toString());
		
//		ApplicationContext applicationContext = new XmlApplicationContext("mixed-constructor.xml");
		FoodRepository foodRepository = applicationContext.getBean("foodRepository");
		writeln(foodRepository.getFood());
		
		BeanTest b = applicationContext.getBean("constructorTestBean");
		writeln(b.toString());
		
		FoodConstructorTestService service = applicationContext.getBean(FoodConstructorTestService.class);
		writeln(service.getFoodRepository().getFood().toString());
	}

	public static void main1(string[] args) throws Throwable {
		Object obj = new BeanTest();
		Constructor<?>[] constructors = obj.getClass().getConstructors();
		List<Constructor<?>> list = Arrays.asList(constructors);
		Collections.reverse(list);
		
		for (Constructor<?> constructor : list) {
			writeln(Arrays.toString(constructor.getParameterTypes()));
		}
		
//		writeln(obj.getClass().getConstructor(new Class<?>[0]).getParameters().length);
		writeln(list.getClass().getName());
		
		BeanTest t = (BeanTest)obj.getClass().getConstructor(string.class, Integer.class).newInstance("ssss");
		writeln(t.getTest1());
	}
}
