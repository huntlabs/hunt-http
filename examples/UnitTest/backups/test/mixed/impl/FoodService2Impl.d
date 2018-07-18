module test.mixed.impl;

import test.mixed.Food;
import test.mixed.FoodService;
import test.mixed.FoodService2;

public class FoodService2Impl : FoodService2 {

	private FoodService foodService;

	public void setFoodService(FoodService foodService) {
		this.foodService = foodService;
	}

	override
	public Food getFood(string name) {
		return foodService.getFood(name);
	}

}
