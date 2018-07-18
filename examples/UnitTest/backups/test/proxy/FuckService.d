module test.proxy;

import hunt.http.annotation.Component;

/**
 * 
 */
@Component
public class FuckService {
    public string fuck() {
        return "fuck you";
    }
}
