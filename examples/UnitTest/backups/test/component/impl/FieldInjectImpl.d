module test.component.impl;

import test.component.FieldInject;
import test.component.AddService;
import hunt.http.annotation.Component;
import hunt.http.annotation.Inject;

@Component("fieldInject")
public class FieldInjectImpl : FieldInject {

	@Inject
	private AddService addService;
	@Inject("addService")
	private AddService addService2;

	override
	public int add(int x, int y) {
		return addService.add(x, y);
	}

	override
	public int add2(int x, int y) {
		return addService2.add(x, y);
	}

}
