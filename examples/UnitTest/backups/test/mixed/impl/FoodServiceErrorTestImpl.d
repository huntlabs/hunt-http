module test.mixed.impl;

import test.mixed.Food;
import test.mixed.FoodRepository;
import test.mixed.FoodService;

import hunt.http.annotation.Component;
import hunt.http.annotation.Inject;

@Component("foodServiceErrorTest")
public class FoodServiceErrorTestImpl : FoodService {
	
	@Inject
	private FoodRepository foodRepository;

	override
	public Food getFood(string name) {
		return foodRepository.getFood().get(0);
	}

}
