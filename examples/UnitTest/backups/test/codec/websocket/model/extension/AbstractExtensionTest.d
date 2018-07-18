module test.codec.websocket.model.extension;

import hunt.http.codec.websocket.stream.WebSocketPolicy;
import hunt.util.Before;
import hunt.util.Rule;
import hunt.util.rules.TestName;

public abstract class AbstractExtensionTest
{
    @Rule
    public TestName testname = new TestName();

    protected ExtensionTool clientExtensions;
    protected ExtensionTool serverExtensions;

    @Before
    public void init()
    {
        clientExtensions = new ExtensionTool(WebSocketPolicy.newClientPolicy());
        serverExtensions = new ExtensionTool(WebSocketPolicy.newServerPolicy());
    }
}
