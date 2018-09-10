module test.http.router.handler;

import hunt.http.$;
import hunt.http.utils.RandomUtils;
import hunt.util.Before;

/**
 * 
 */
abstract public class AbstractHttpHandlerTest {
    protected final string host = "localhost";
    protected static int port = 8000;
    protected string uri;

    @Before
    public void init() {
        port = (int)RandomUtils.random(3000, 65534);
        uri = $.uri.newURIBuilder("http", host, port).toString();
        writeln(uri);
    }
}
