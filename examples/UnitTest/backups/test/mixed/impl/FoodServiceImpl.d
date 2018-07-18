module test.mixed.impl;

import test.mixed.Food;
import test.mixed.FoodRepository;
import test.mixed.FoodService;

import hunt.http.annotation.Component;
import hunt.http.annotation.Inject;

@Component("foodService")
public class FoodServiceImpl : FoodService {

	@Inject("foodRepository")
	private FoodRepository foodRepository;

	override
	public Food getFood(string name) {
		for (Food f : foodRepository.getFood()) {
			if (f.getName().equals(name))
				return f;
		}
		return null;
	}

}
