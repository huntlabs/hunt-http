module test.websocket;

import hunt.util.Test;
import hunt.util.runner.RunWith;
import hunt.util.runners.Parameterized;

import java.util.Collections;

/**
 * 
 */

public class TestFragmentExtension extends TestWebSocket {

    
    override
    public void test() {
        testServerAndClient(Collections.singletonList("fragment"));
    }
}
