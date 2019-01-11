module test.mixed.impl;

import hunt.collection.List;

import test.mixed.Food;
import test.mixed.FoodRepository;

public class FoodRepositoryImpl : FoodRepository {

	private List<Food> food;
	
	public FoodRepositoryImpl() {}
	
	public FoodRepositoryImpl(List<Food> food) {
		this.food = food;
	}

	override
	public List<Food> getFood() {
		return food;
	}

	public void setFood(List<Food> food) {
		this.food = food;
	}

}
