module test.proxy;

import hunt.http.annotation.Component;

/**
 * 
 */
@Component
public class SexService {

    public string getSex() {
        return "female";
    }
}
