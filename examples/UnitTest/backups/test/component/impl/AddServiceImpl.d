module test.component.impl;

import test.component.AddService;
import hunt.http.annotation.Component;

@Component("addService")
public class AddServiceImpl : AddService {
	private int i = 0;

	override
	public int add(int x, int y) {
		return x + y;
	}

	override
	public int getI() {
		return i++;
	}

}
