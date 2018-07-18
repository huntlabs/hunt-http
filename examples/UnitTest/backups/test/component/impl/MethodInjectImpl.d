module test.component.impl;

import hunt.http.annotation.Component;
import hunt.http.annotation.Inject;

import test.component.AddService;
import test.component.MethodInject;

@Component("methodInject")
public class MethodInjectImpl : MethodInject {

	private AddService addService;

	@Inject
	public void init(AddService addService) {
		this.addService = addService;
	}

	override
	public int add(int x, int y) {
		return addService.add(x, y);
	}

}
